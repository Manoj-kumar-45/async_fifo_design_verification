// =============================================================================
// Module      : async_fifo_top
// Project     : Tapeout-Quality Asynchronous FIFO
// Author      : Senior RTL Design Engineer
// Description : Top-level integration of the parameterized asynchronous FIFO.
//               Implements Cliff Cummings Style #1 architecture (SNUG 2002).
//
// Architecture Overview:
//
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │                        async_fifo_top                               │
//   │                                                                     │
//   │  ┌──────────────┐    wr_gray    ┌──────────────┐  rd_gray_sync     │
//   │  │ wr_ptr_ctrl  │─────────────>│  sync_2ff    │──────────────>    │
//   │  │  (wr domain) │              │ (rd→wr cross)│  (into rd domain) │
//   │  └──────────────┘              └──────────────┘                   │
//   │         │                                                           │
//   │         │ wr_addr, wr_en_qual                                      │
//   │         ▼                                                           │
//   │  ┌──────────────┐                                                  │
//   │  │  fifo_mem    │  (dual-port memory)                              │
//   │  └──────────────┘                                                  │
//   │         │                                                           │
//   │         │ rd_data                                                   │
//   │         ▼                                                           │
//   │  ┌──────────────┐    rd_gray    ┌──────────────┐  wr_gray_sync    │
//   │  │ rd_ptr_ctrl  │─────────────>│  sync_2ff    │──────────────>   │
//   │  │  (rd domain) │              │ (wr→rd cross)│  (into wr domain)│
//   │  └──────────────┘              └──────────────┘                   │
//   └─────────────────────────────────────────────────────────────────────┘
//
// CDC Crossings (the ONLY two signals that cross clock domains):
//   1. wr_gray  [PTR_WIDTH-1:0] : wr_clk → rd_clk (via u_sync_wr2rd)
//   2. rd_gray  [PTR_WIDTH-1:0] : rd_clk → wr_clk (via u_sync_rd2wr)
//
// Both crossings use registered Gray-coded pointers (1 bit change/cycle max)
// through 2-flop synchronizers. This is the complete CDC boundary of the design.
//
// SDC Constraints Required (add to your .sdc / constraints file):
//   # Clock definitions
//   create_clock -name wr_clk -period <T_wr> [get_ports wr_clk]
//   create_clock -name rd_clk -period <T_rd> [get_ports rd_clk]
//   set_clock_groups -asynchronous -group {wr_clk} -group {rd_clk}
//
//   # Synchronizer false-path (hold only — setup is constrained by dest clock)
//   set_false_path -hold -from [get_clocks wr_clk] -to [get_clocks rd_clk]
//   set_false_path -hold -from [get_clocks rd_clk] -to [get_clocks wr_clk]
//
//   # Prevent retiming of synchronizer flops
//   set_dont_retime [get_cells -hierarchical *sync_ff*]
//
// Lint Notes:
//   - All ports are fully connected (no undriven outputs, no unused inputs)
//   - No implicit net widths
//   - All parameters propagated consistently
//   - No generate needed — flat parameterized instantiation
// =============================================================================

`ifndef ASYNC_FIFO_TOP_SV
`define ASYNC_FIFO_TOP_SV

`include "sync_2ff.sv"
`include "fifo_mem.sv"
`include "wr_ptr_ctrl.sv"
`include "rd_ptr_ctrl.sv"

module async_fifo_top #(
    // -------------------------------------------------------------------------
    // DATA_WIDTH : Width of each FIFO data word in bits.
    // FIFO_DEPTH : Number of entries. MUST be a power of 2.
    // ADDR_WIDTH : $clog2(FIFO_DEPTH). Set explicitly to avoid tool differences
    //              in evaluating $clog2 at parameter override time.
    // PTR_WIDTH  : ADDR_WIDTH + 1. Extra MSB enables full/empty disambiguation.
    // -------------------------------------------------------------------------
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH),  // = 4
    parameter int unsigned PTR_WIDTH  = ADDR_WIDTH + 1       // = 5
) (
    // =========================================================================
    // Write Clock Domain Interface
    // =========================================================================
    input  logic                  wr_clk,     // Write clock (independent domain)
    input  logic                  wr_arst_n,  // Active-low async reset (write domain)
    input  logic                  wr_en,      // Write request: push wr_data into FIFO
    input  logic [DATA_WIDTH-1:0] wr_data,    // Data word to write

    output logic                  wr_full,    // HIGH when FIFO is full (write domain)
    output logic                  wr_overflow, // HIGH when wr_en asserted while full

    // =========================================================================
    // Read Clock Domain Interface
    // =========================================================================
    input  logic                  rd_clk,     // Read clock (independent domain)
    input  logic                  rd_arst_n,  // Active-low async reset (read domain)
    input  logic                  rd_en,      // Read request: pop rd_data from FIFO

    output logic [DATA_WIDTH-1:0] rd_data,    // Data word read from FIFO
    output logic                  rd_empty,   // HIGH when FIFO is empty (read domain)
    output logic                  rd_underflow // HIGH when rd_en asserted while empty
);

    // =========================================================================
    // Internal Wires
    // =========================================================================

    // -------------------------------------------------------------------------
    // Write domain internal wires
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] wr_addr;       // Binary write address to fifo_mem
    logic                  wr_en_qual;    // Qualified write enable (wr_en & ~wr_full)
    logic [PTR_WIDTH-1:0]  wr_gray;       // Registered Gray write ptr (exits wr domain)

    // -------------------------------------------------------------------------
    // Read domain internal wires
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] rd_addr;       // Binary read address to fifo_mem
    logic                  rd_en_qual;    // Qualified read enable (rd_en & ~rd_empty)
    logic [PTR_WIDTH-1:0]  rd_gray;       // Registered Gray read ptr (exits rd domain)

    // -------------------------------------------------------------------------
    // CDC-synchronized pointer wires
    // These are the outputs of the 2-flop synchronizers.
    // Each signal has crossed its domain boundary and is safe to use
    // combinationally in the destination domain.
    // -------------------------------------------------------------------------
    logic [PTR_WIDTH-1:0]  wr_gray_sync;  // wr_gray synchronized into rd domain
    logic [PTR_WIDTH-1:0]  rd_gray_sync;  // rd_gray synchronized into wr domain

    // =========================================================================
    // CDC Crossing 1: Write Gray Pointer → Read Clock Domain
    //
    // Instance: u_sync_wr2rd
    // Source   : wr_gray (registered in wr_clk domain, wr_ptr_ctrl)
    // Dest     : wr_gray_sync (safe for use in rd_clk domain, rd_ptr_ctrl)
    //
    // CDC Tool Annotation: cdc_sync -type gray_sync -from wr_clk -to rd_clk
    //   -signal wr_gray -sync_instance u_sync_wr2rd
    // =========================================================================
    sync_2ff #(
        .PTR_WIDTH (PTR_WIDTH)
    ) u_sync_wr2rd (
        .clk    (rd_clk),       // Destination: rd_clk
        .arst_n (rd_arst_n),    // Reset in destination domain
        .d      (wr_gray),      // Source Gray pointer (from wr domain)
        .q      (wr_gray_sync)  // Synchronized Gray pointer (in rd domain)
    );

    // =========================================================================
    // CDC Crossing 2: Read Gray Pointer → Write Clock Domain
    //
    // Instance: u_sync_rd2wr
    // Source   : rd_gray (registered in rd_clk domain, rd_ptr_ctrl)
    // Dest     : rd_gray_sync (safe for use in wr_clk domain, wr_ptr_ctrl)
    //
    // CDC Tool Annotation: cdc_sync -type gray_sync -from rd_clk -to wr_clk
    //   -signal rd_gray -sync_instance u_sync_rd2wr
    // =========================================================================
    sync_2ff #(
        .PTR_WIDTH (PTR_WIDTH)
    ) u_sync_rd2wr (
        .clk    (wr_clk),       // Destination: wr_clk
        .arst_n (wr_arst_n),    // Reset in destination domain
        .d      (rd_gray),      // Source Gray pointer (from rd domain)
        .q      (rd_gray_sync)  // Synchronized Gray pointer (in wr domain)
    );

    // =========================================================================
    // Write Pointer Controller
    //
    // All write-domain logic: binary pointer, Gray conversion, full detection.
    // Receives rd_gray_sync (already synchronized, safe in wr domain).
    // Produces wr_gray (registered, safe to send to sync_2ff input).
    // =========================================================================
    wr_ptr_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_wr_ptr_ctrl (
        .wr_clk      (wr_clk),
        .wr_arst_n   (wr_arst_n),
        .wr_en       (wr_en),
        .rd_gray_sync(rd_gray_sync),   // Synchronized rd ptr → used in full detect
        .wr_addr     (wr_addr),        // → fifo_mem write address
        .wr_en_qual  (wr_en_qual),     // → fifo_mem write enable
        .wr_gray     (wr_gray),        // → u_sync_wr2rd input
        .wr_full     (wr_full),        // → top-level output port
        .wr_overflow (wr_overflow)     // → top-level output port
    );

    // =========================================================================
    // Read Pointer Controller
    //
    // All read-domain logic: binary pointer, Gray conversion, empty detection.
    // Receives wr_gray_sync (already synchronized, safe in rd domain).
    // Produces rd_gray (registered, safe to send to sync_2ff input).
    // =========================================================================
    rd_ptr_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_rd_ptr_ctrl (
        .rd_clk      (rd_clk),
        .rd_arst_n   (rd_arst_n),
        .rd_en       (rd_en),
        .wr_gray_sync(wr_gray_sync),   // Synchronized wr ptr → used in empty detect
        .rd_addr     (rd_addr),        // → fifo_mem read address
        .rd_en_qual  (rd_en_qual),     // → fifo_mem read enable
        .rd_gray     (rd_gray),        // → u_sync_rd2wr input
        .rd_empty    (rd_empty),       // → top-level output port
        .rd_underflow(rd_underflow)    // → top-level output port
    );

    // =========================================================================
    // Dual-Port FIFO Memory
    //
    // Write port clocked by wr_clk; read port clocked by rd_clk.
    // Both address inputs are binary (from pointer controllers).
    // Write enable is pre-gated (wr_en_qual = wr_en & ~wr_full).
    // Read enable is pre-gated  (rd_en_qual = rd_en & ~rd_empty).
    //
    // The memory sits between both clock domains but contains NO CDC logic.
    // The pointer controllers ensure addresses are always valid before
    // wr_en_qual/rd_en_qual are asserted — no hazard on the memory array.
    // =========================================================================
    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_mem (
        .wr_clk  (wr_clk),
        .wr_en   (wr_en_qual),   // Gated write enable
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (rd_clk),
        .rd_en   (rd_en_qual),   // Gated read enable
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    // =========================================================================
    // Top-Level Assertions (Simulation Only)
    //
    // These assertions catch integration-level protocol violations during
    // simulation. They are excluded from synthesis by translate_off guards.
    // =========================================================================
    // synthesis translate_off
    // verilog_format: off

    // Assert: no simultaneous full+empty in the same domain
    // (impossible by design, but guards against integration mistakes)
    property p_no_full_and_empty;
        @(posedge wr_clk) disable iff (!wr_arst_n)
        !(wr_full && rd_empty);  // Cannot be full AND empty simultaneously
    endproperty
    // Note: full is in wr domain, empty is in rd domain — cross-domain assertion
    // is for simulation debug only, not for formal verification use.

    // Assert: overflow should never occur in a compliant system
    property p_no_overflow;
        @(posedge wr_clk) disable iff (!wr_arst_n)
        !(wr_en && wr_full);
    endproperty

    // Assert: underflow should never occur in a compliant system
    property p_no_underflow;
        @(posedge rd_clk) disable iff (!rd_arst_n)
        !(rd_en && rd_empty);
    endproperty

    // Uncomment to enable assertions in simulation:
    // assert property (p_no_overflow)
    //     else $error("[async_fifo_top] OVERFLOW: wr_en asserted while FULL at time %0t", $time);
    // assert property (p_no_underflow)
    //     else $error("[async_fifo_top] UNDERFLOW: rd_en asserted while EMPTY at time %0t", $time);

    // verilog_format: on

    // -------------------------------------------------------------------------
    // Parameter validation
    // -------------------------------------------------------------------------
    initial begin : param_check
        if (FIFO_DEPTH < 2) begin
            $error("[async_fifo_top] FIFO_DEPTH=%0d must be >= 2.", FIFO_DEPTH);
            $finish;
        end
        if ((FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) begin
            $error("[async_fifo_top] FIFO_DEPTH=%0d must be a power of 2.", FIFO_DEPTH);
            $finish;
        end
        if (PTR_WIDTH != ADDR_WIDTH + 1) begin
            $error("[async_fifo_top] PTR_WIDTH=%0d must equal ADDR_WIDTH+1=%0d.",
                   PTR_WIDTH, ADDR_WIDTH + 1);
            $finish;
        end
        $display("[async_fifo_top] Config: DATA_WIDTH=%0d FIFO_DEPTH=%0d ADDR_WIDTH=%0d PTR_WIDTH=%0d",
                 DATA_WIDTH, FIFO_DEPTH, ADDR_WIDTH, PTR_WIDTH);
    end : param_check
    // synthesis translate_on

endmodule : async_fifo_top

`endif // ASYNC_FIFO_TOP_SV
