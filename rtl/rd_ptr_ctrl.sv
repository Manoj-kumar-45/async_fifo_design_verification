// =============================================================================
// Module      : rd_ptr_ctrl
// Project     : Tapeout-Quality Asynchronous FIFO
// Author      : Senior RTL Design Engineer
// Description : Read-domain pointer controller for the asynchronous FIFO.
//               Implements Cliff Cummings Style #1 read-side logic:
//                 1. Binary read pointer (for memory addressing)
//                 2. Gray-code read pointer (for CDC crossing to write domain)
//                 3. Predictive empty flag generation
//
// Empty Detection Algorithm:
//   The FIFO is empty when the NEXT read Gray pointer equals the synchronized
//   write Gray pointer. Because the read pointer is trying to catch the write
//   pointer (not lap it), no bit inversion is needed — all bits compare equal.
//   This is in contrast to full detection which requires top-2-bit inversion.
//
//   Using rd_gray_next (predictive) ensures empty is asserted on the SAME
//   cycle the last word is read — not one cycle late. Without prediction, the
//   consumer would see empty only AFTER it attempted a second read of the
//   last valid word, returning stale data.
//
// CDC Notes   : rd_gray (registered) is the only signal leaving this domain.
//               It transitions at most 1 bit per rd_clk cycle (Gray property).
//               wr_gray_sync arrives from a 2-flop synchronizer — metastability-
//               free and safe for use in combinational logic in this domain.
//
// Synthesis   : rd_empty is registered. All domain-crossing outputs are
//               registered Gray-coded pointers. No combinational outputs
//               cross clock domain boundaries.
// =============================================================================

`ifndef RD_PTR_CTRL_SV
`define RD_PTR_CTRL_SV

module rd_ptr_ctrl #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4,    // $clog2(FIFO_DEPTH)
    parameter int unsigned PTR_WIDTH  = 5     // ADDR_WIDTH + 1
) (
    // -------------------------------------------------------------------------
    // Read Clock Domain
    // -------------------------------------------------------------------------
    input  logic                  rd_clk,       // Read clock
    input  logic                  rd_arst_n,    // Active-low async reset (read domain)
    input  logic                  rd_en,        // Read request from downstream logic

    // -------------------------------------------------------------------------
    // Synchronized Write Pointer (arrives from wr_ptr_ctrl via sync_2ff)
    // This signal is stable and metastability-free — it has passed through
    // a 2-flop synchronizer clocked on rd_clk.
    // -------------------------------------------------------------------------
    input  logic [PTR_WIDTH-1:0]  wr_gray_sync, // Synchronized wr Gray ptr (in rd domain)

    // -------------------------------------------------------------------------
    // Outputs to fifo_mem
    // -------------------------------------------------------------------------
    output logic [ADDR_WIDTH-1:0] rd_addr,      // Binary read address (LSBs of rd_ptr)
    output logic                  rd_en_qual,   // Qualified read enable = rd_en & ~rd_empty

    // -------------------------------------------------------------------------
    // Outputs for CDC crossing (registered Gray pointer → sync_2ff → wr domain)
    // -------------------------------------------------------------------------
    output logic [PTR_WIDTH-1:0]  rd_gray,      // Gray-coded read pointer (registered)

    // -------------------------------------------------------------------------
    // Status Flags
    // -------------------------------------------------------------------------
    output logic                  rd_empty,     // Registered EMPTY flag (read domain)
    output logic                  rd_underflow  // Registered underflow indicator (rd domain)
);

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // rd_ptr_bin  : Full-width binary read pointer (PTR_WIDTH bits).
    //               MSB is the wrap-around disambiguation bit.
    //               ADDR_WIDTH LSBs index the memory read address.
    logic [PTR_WIDTH-1:0] rd_ptr_bin;

    // rd_ptr_bin_next : Combinational next value of rd_ptr_bin.
    //                   Incremented on a qualified read.
    logic [PTR_WIDTH-1:0] rd_ptr_bin_next;

    // rd_gray_next : Gray code of rd_ptr_bin_next.
    //                Used for PREDICTIVE empty detection.
    //                Compare against wr_gray_sync to detect empty one cycle early.
    logic [PTR_WIDTH-1:0] rd_gray_next;

    // rd_empty_next : Combinational empty flag for the next state.
    //                 Registered into rd_empty on posedge rd_clk.
    logic                 rd_empty_next;

    // =========================================================================
    // Qualified Read Enable
    //
    // A read is only performed if:
    //   (a) Downstream logic requests a read (rd_en = 1), AND
    //   (b) The FIFO is not empty (rd_empty = 0)
    //
    // Uses registered rd_empty (not combinational) for a glitch-free gate.
    // This qualified signal drives the memory read enable and pointer increment.
    // =========================================================================
    assign rd_en_qual = rd_en & ~rd_empty;

    // =========================================================================
    // Next Binary Pointer Computation
    //
    // Increment rd_ptr_bin by 1 on a qualified read.
    // The increment wraps at 2^PTR_WIDTH — correct for power-of-two FIFO depth.
    // When rd_en_qual is LOW, rd_ptr_bin_next holds the current value.
    // =========================================================================
    always_comb begin : next_bin_ptr
        rd_ptr_bin_next = rd_ptr_bin + {{(PTR_WIDTH-1){1'b0}}, rd_en_qual};
    end : next_bin_ptr

    // =========================================================================
    // Binary-to-Gray Conversion (Next Pointer)
    //
    // Standard XOR-shift Gray conversion: Gray(N) = N XOR (N >> 1)
    //
    // Converting the NEXT binary value serves two purposes:
    //   1. Predictive empty detection (rd_gray_next vs wr_gray_sync)
    //   2. The registered rd_gray output will capture rd_gray_next, making
    //      rd_gray represent the Gray code of the current binary pointer
    //      after the clock edge — correct and consistent.
    //
    // The XOR tree is purely combinational with no latches or registers.
    // Synthesis will implement this as a small XOR gate network.
    // =========================================================================
    always_comb begin : bin_to_gray_next
        rd_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);
    end : bin_to_gray_next

    // =========================================================================
    // Registered Read Pointer (Binary and Gray)
    //
    // Both pointers register on posedge rd_clk with asynchronous reset.
    //
    // rd_ptr_bin: binary pointer, resets to 0.
    // rd_gray   : Gray pointer, resets to 0 (Gray(0) = 0).
    //
    // CRITICAL — rd_gray must be registered before CDC crossing:
    //   The combinational XOR conversion produces glitches during the
    //   brief moment when rd_ptr_bin transitions. If rd_gray_next were
    //   connected directly to the synchronizer input, a multi-bit glitch
    //   could appear during the XOR evaluation window. Even though each
    //   glitch lasts only picoseconds, the synchronizer input would sample
    //   an invalid multi-bit value — violating the Gray-code single-bit
    //   change precondition.
    //
    //   Registering rd_gray eliminates ALL combinational glitches.
    //   The synchronizer input sees a clean, registered signal that changes
    //   exactly 1 bit per rd_clk cycle.
    // =========================================================================
    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : rd_ptr_reg
        if (!rd_arst_n) begin
            rd_ptr_bin <= {PTR_WIDTH{1'b0}};
            rd_gray    <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_ptr_bin <= rd_ptr_bin_next;
            rd_gray    <= rd_gray_next;
        end
    end : rd_ptr_reg

    // =========================================================================
    // Read Address to Memory
    //
    // Lower ADDR_WIDTH bits of binary read pointer index the memory.
    // The MSB wrap bit is excluded — it is only used in empty/full detection.
    // Combinational assignment from registered rd_ptr_bin — glitch-free.
    // =========================================================================
    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================================
    // Predictive Empty Flag Generation
    //
    // Empty condition: the read pointer has caught up to the write pointer.
    //
    //   SIMPLE EQUALITY: rd_gray_next == wr_gray_sync
    //
    //   Unlike the full condition, NO bit inversion is needed here.
    //   When wr_ptr == rd_ptr (all PTR_WIDTH bits equal), the FIFO is empty —
    //   this is true at reset (both = 0) and whenever the reader has consumed
    //   all available data.
    //
    //   WHY NO BIT INVERSION:
    //     Full requires inversion because wr has LAPPED rd (wr is one full
    //     FIFO_DEPTH ahead). Empty means rd has CAUGHT UP to wr — same address,
    //     same wrap bit. All bits are identical.
    //
    //   PREDICTIVE (using rd_gray_next):
    //     If we compare rd_gray (current) to wr_gray_sync, the empty flag
    //     would assert one cycle AFTER the last word is consumed. During that
    //     cycle, rd_en could still be asserted, causing a second read of the
    //     same address — returning stale/duplicate data. Predictive comparison
    //     prevents this by asserting empty on the same cycle as the last read.
    //
    //   CONSERVATIVE NATURE:
    //     wr_gray_sync is the write pointer as seen 2 rd_clk cycles ago.
    //     If the write domain added entries in the meantime, wr_gray_sync
    //     lags behind reality — so we may see "empty" when 1-2 entries
    //     have actually been written. This is SAFE and CORRECT:
    //       - We never read data that wasn't written (no underflow on valid data)
    //       - We may temporarily not see newly written data (latency = 2 clocks)
    //       - This is the fundamental latency trade-off of asynchronous FIFOs
    // =========================================================================
    always_comb begin : empty_detect
        rd_empty_next = (rd_gray_next == wr_gray_sync);
    end : empty_detect

    // =========================================================================
    // Registered Empty Flag
    //
    // rd_empty is registered — not combinational. Reasons identical to wr_full:
    //   1. Eliminates glitches from the combinational comparison path
    //   2. Provides a clean, stable signal for rd_en_qual gating
    //   3. STA tools can correctly constrain a registered flag output
    //
    // Reset: rd_empty asserts (FIFO empty after reset = correct initial state).
    //        Note: wr_full deasserts on reset (empty, not full).
    //        Both domains reset to pointer=0, so rd_gray_next(0)==wr_gray_sync(0)
    //        → rd_empty_next = 1 immediately after reset, which is correct.
    // =========================================================================
    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : empty_reg
        if (!rd_arst_n) begin
            rd_empty <= 1'b1;  // FIFO is empty after reset
        end else begin
            rd_empty <= rd_empty_next;
        end
    end : empty_reg

    // =========================================================================
    // Underflow Detection
    //
    // Underflow: downstream asserts rd_en when FIFO is already empty.
    // This is a protocol violation — the consumer should check rd_empty first.
    // The indicator is registered and intended for debug/status monitoring.
    // No data corruption occurs because rd_en_qual is gated by ~rd_empty.
    //
    // Silicon bring-up: underflow is routed to a status register for debug.
    // =========================================================================
    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : underflow_reg
        if (!rd_arst_n) begin
            rd_underflow <= 1'b0;
        end else begin
            rd_underflow <= rd_en & rd_empty;
        end
    end : underflow_reg

    // =========================================================================
    // Parameter Validation
    // =========================================================================
    // synthesis translate_off
    initial begin : param_check
        if (PTR_WIDTH != ADDR_WIDTH + 1) begin
            $error("[rd_ptr_ctrl] PTR_WIDTH=%0d must equal ADDR_WIDTH+1=%0d.",
                   PTR_WIDTH, ADDR_WIDTH + 1);
            $finish;
        end
        if (ADDR_WIDTH != $clog2(FIFO_DEPTH)) begin
            $error("[rd_ptr_ctrl] ADDR_WIDTH=%0d != $clog2(FIFO_DEPTH=%0d)=%0d.",
                   ADDR_WIDTH, FIFO_DEPTH, $clog2(FIFO_DEPTH));
            $finish;
        end
    end : param_check
    // synthesis translate_on

endmodule : rd_ptr_ctrl

`endif // RD_PTR_CTRL_SV
