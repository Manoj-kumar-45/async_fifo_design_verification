// =============================================================================
// Module      : wr_ptr_ctrl
// Project     : Tapeout-Quality Asynchronous FIFO
// Author      : Senior RTL Design Engineer
// Description : Write-domain pointer controller for the asynchronous FIFO.
//               Implements Cliff Cummings Style #1 write-side logic:
//                 1. Binary write pointer (for memory addressing)
//                 2. Gray-code write pointer (for CDC crossing to read domain)
//                 3. Predictive full flag generation
//                 4. Instantiation of read-pointer synchronizer (rd→wr domain)
//
// Full Detection Algorithm:
//   The FIFO is full when the NEXT write pointer (in Gray code) would equal
//   a value that — in binary — is exactly FIFO_DEPTH ahead of the current
//   synchronized read pointer. In Gray code space, this corresponds to:
//     - Top 2 MSBs of wr_gray_next INVERTED relative to rd_gray_sync
//     - All remaining LSBs EQUAL to rd_gray_sync
//   This is the mathematically correct Gray-domain full comparison derived
//   from Cliff Cummings' SNUG 2002 paper.
//
// WHY PREDICTIVE (NEXT) POINTER:
//   Comparing the CURRENT wr_gray to rd_gray_sync would assert full one cycle
//   AFTER the last write slot is consumed. This means the upstream write
//   interface would attempt one extra write into a full FIFO before seeing
//   the full flag — causing data corruption. Using wr_gray_next ensures
//   the full flag is asserted on the SAME cycle the last slot is taken.
//
// CDC Notes   : wr_gray (registered) is the only signal leaving this domain.
//               It transitions at most 1 bit per wr_clk cycle (Gray property).
//               rd_gray_sync arrives from a 2-flop synchronizer — safe to use
//               in combinational logic within this domain.
//
// Synthesis   : wr_full is registered. No combinational full flag output.
//               All outputs are either registered or derived from registered
//               signals — no glitchy combinational outputs cross domains.
// =============================================================================

`ifndef WR_PTR_CTRL_SV
`define WR_PTR_CTRL_SV

`include "sync_2ff.sv"

module wr_ptr_ctrl #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4,    // $clog2(FIFO_DEPTH)
    parameter int unsigned PTR_WIDTH  = 5     // ADDR_WIDTH + 1
) (
    // -------------------------------------------------------------------------
    // Write Clock Domain
    // -------------------------------------------------------------------------
    input  logic                  wr_clk,       // Write clock
    input  logic                  wr_arst_n,    // Active-low async reset (write domain)
    input  logic                  wr_en,        // Write request from upstream logic

    // -------------------------------------------------------------------------
    // Synchronized Read Pointer (arrives from rd_ptr_ctrl via sync_2ff)
    // This signal is stable and metastability-free — it has passed through
    // a 2-flop synchronizer clocked on wr_clk.
    // -------------------------------------------------------------------------
    input  logic [PTR_WIDTH-1:0]  rd_gray_sync, // Synchronized rd Gray ptr (in wr domain)

    // -------------------------------------------------------------------------
    // Outputs to fifo_mem
    // -------------------------------------------------------------------------
    output logic [ADDR_WIDTH-1:0] wr_addr,      // Binary write address (LSBs of wr_ptr)
    output logic                  wr_en_qual,   // Qualified write enable = wr_en & ~wr_full

    // -------------------------------------------------------------------------
    // Outputs for CDC crossing (registered Gray pointer → sync_2ff → rd domain)
    // -------------------------------------------------------------------------
    output logic [PTR_WIDTH-1:0]  wr_gray,      // Gray-coded write pointer (registered)

    // -------------------------------------------------------------------------
    // Status Flags
    // -------------------------------------------------------------------------
    output logic                  wr_full,      // Registered FULL flag (write domain)
    output logic                  wr_overflow   // Registered overflow indicator (wr domain)
);

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // wr_ptr_bin  : Full-width binary write pointer (PTR_WIDTH bits).
    //               The extra MSB (bit PTR_WIDTH-1) is the wrap-around bit.
    //               It toggles on each full traversal of the FIFO depth.
    //               ADDR_WIDTH LSBs are used as the memory write address.
    logic [PTR_WIDTH-1:0] wr_ptr_bin;

    // wr_ptr_bin_next : Combinational next value of wr_ptr_bin.
    //                   Used for predictive full detection AND as the D-input
    //                   to wr_ptr_bin register (when write is qualified).
    logic [PTR_WIDTH-1:0] wr_ptr_bin_next;

    // wr_gray_next : Gray code of wr_ptr_bin_next.
    //                Used for PREDICTIVE full detection — compare against
    //                rd_gray_sync to determine if the NEXT write would fill
    //                the FIFO. Prevents off-by-one overflow.
    logic [PTR_WIDTH-1:0] wr_gray_next;

    // wr_full_next : Combinational full flag for the NEXT state.
    //                Registered into wr_full on the next wr_clk edge.
    logic                 wr_full_next;

    // =========================================================================
    // Qualified Write Enable
    //
    // A write is only performed if:
    //   (a) The upstream logic requests a write (wr_en = 1), AND
    //   (b) The FIFO is not full (wr_full = 0)
    //
    // This qualified signal gates both the pointer increment and the memory
    // write enable. Using the REGISTERED wr_full (not combinational) ensures
    // the gate is glitch-free and synthesis-friendly.
    // =========================================================================
    assign wr_en_qual = wr_en & ~wr_full;

    // =========================================================================
    // Next Binary Pointer Computation
    //
    // Increment wr_ptr_bin by 1 on a qualified write.
    // The +1 increment wraps naturally at 2^PTR_WIDTH due to binary arithmetic,
    // providing the correct wrap-around behavior.
    //
    // When wr_en_qual is LOW (no write or full), wr_ptr_bin_next holds the
    // current pointer value — no increment.
    // =========================================================================
always_comb begin
    if (wr_en_qual)
        wr_ptr_bin_next = wr_ptr_bin + 1;
    else
        wr_ptr_bin_next = wr_ptr_bin;
end
    // =========================================================================
    // Binary-to-Gray Conversion (Next Pointer)
    //
    // Gray(N) = N XOR (N >> 1)
    //
    // This is the standard single-right-shift XOR Gray conversion.
    // It guarantees Hamming distance = 1 between consecutive Gray values,
    // which is the CDC safety precondition for the 2-flop synchronizer.
    //
    // We convert the NEXT binary pointer (not current) for two reasons:
    //   1. Predictive full detection (compare next Gray to rd_gray_sync)
    //   2. The registered Gray output (wr_gray) captures wr_gray_next on
    //      the clock edge — so wr_gray is always the Gray of the CURRENT
    //      binary pointer value after the clock edge. This is correct.
    // =========================================================================
    always_comb begin : bin_to_gray_next
        wr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);
    end : bin_to_gray_next

    // =========================================================================
    // Registered Write Pointer (Binary and Gray)
    //
    // Both pointers are registered on posedge wr_clk with async reset.
    //
    // wr_ptr_bin: binary pointer, resets to 0.
    // wr_gray   : Gray pointer, resets to 0 (Gray(0) = 0).
    //
    // CRITICAL: wr_gray is registered here before crossing to the read domain.
    // Registering eliminates any combinational glitches from the XOR tree.
    // Only a registered, glitch-free signal may safely enter a 2-flop synchronizer.
    // A combinational Gray output connected directly to a synchronizer input
    // would introduce multi-bit glitches during the conversion — defeating the
    // entire purpose of Gray coding.
    // =========================================================================
    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : wr_ptr_reg
        if (!wr_arst_n) begin
            wr_ptr_bin <= {PTR_WIDTH{1'b0}};
            wr_gray    <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_ptr_bin <= wr_ptr_bin_next;
            wr_gray    <= wr_gray_next;
        end
    end : wr_ptr_reg

    // =========================================================================
    // Write Address to Memory
    //
    // The memory address is the lower ADDR_WIDTH bits of the binary pointer.
    // The MSB (wrap bit) is NOT used as an address — it is only used for
    // full/empty detection.
    //
    // assign (combinational): The address is derived directly from wr_ptr_bin.
    // It is stable one cycle before the write is clocked into memory because
    // wr_ptr_bin was registered on the previous clock edge.
    // =========================================================================
    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================================
    // Predictive Full Flag Generation
    //
    // Full condition in Gray code space:
    //
    //   The write pointer has lapped the read pointer when binary wr_ptr is
    //   exactly FIFO_DEPTH ahead of binary rd_ptr. In 5-bit Gray code
    //   (for FIFO_DEPTH=16, PTR_WIDTH=5), this means:
    //
    //     Bit [4] (MSB)  : wr_gray_next[4] != rd_gray_sync[4]  → INVERTED
    //     Bit [3]        : wr_gray_next[3] != rd_gray_sync[3]  → INVERTED
    //     Bits [2:0]     : wr_gray_next[2:0] == rd_gray_sync[2:0] → EQUAL
    //
    //   WHY MSB and MSB-1 are inverted:
    //     Consider wr_ptr=N and rd_ptr=N+FIFO_DEPTH (in binary, one full lap
    //     ahead). Gray(N) and Gray(N+FIFO_DEPTH) differ in exactly bits
    //     [PTR_WIDTH-1] and [PTR_WIDTH-2]. This is proven from the structure
    //     of reflected Gray codes — adding FIFO_DEPTH (a power-of-two shift)
    //     to a binary number flips the top two bits in its Gray representation.
    //
    //   PREDICTIVE: using wr_gray_next (not wr_gray) detects full BEFORE the
    //   last entry is written, asserting wr_full on the same cycle as the
    //   last write — not one cycle late.
    // =========================================================================
    // =========================================================================
    // Full Detection — Safe Bit-Slice Version
    //
    // For PTR_WIDTH >= 3 (FIFO_DEPTH >= 4, enforced by param check below):
    //   Bits [PTR_WIDTH-1] and [PTR_WIDTH-2] must be INVERTED (lapped MSBs).
    //   Bits [PTR_WIDTH-3:0] must be EQUAL (same lower address).
    //
    // The lower-bit slice width = PTR_WIDTH - 2.
    // For PTR_WIDTH=3: slice is [0:0]  (1 bit)
    // For PTR_WIDTH=4: slice is [1:0]  (2 bits)
    // For PTR_WIDTH=5: slice is [2:0]  (3 bits) ← our default
    //
    // NOTE: PTR_WIDTH=2 (FIFO_DEPTH=2) would give a zero-width or negative
    // slice — prevented by the parameter check enforcing FIFO_DEPTH >= 4.
    // =========================================================================
    localparam int unsigned LOWER_WIDTH = PTR_WIDTH - 2; // >= 1 when PTR_WIDTH >= 3

    always_comb begin : full_detect
        wr_full_next =
            (wr_gray_next[PTR_WIDTH-1]            != rd_gray_sync[PTR_WIDTH-1])  &&
            (wr_gray_next[PTR_WIDTH-2]            != rd_gray_sync[PTR_WIDTH-2])  &&
            (wr_gray_next[LOWER_WIDTH-1:0]        == rd_gray_sync[LOWER_WIDTH-1:0]);
    end : full_detect

    // =========================================================================
    // Registered Full Flag
    //
    // wr_full is registered — not combinational. This is mandatory because:
    //   1. A combinational full flag driven by synchronized rd_gray_sync could
    //      glitch if wr_gray_next and rd_gray_sync change in the same cycle.
    //   2. Downstream logic (wr_en_qual gate, overflow detection) relies on a
    //      glitch-free full flag.
    //   3. STA tools can properly constrain a registered output; a combinational
    //      flag with synchronizer input makes timing analysis ambiguous.
    //
    // Reset: wr_full deasserts (FIFO empty after reset).
    // =========================================================================
    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : full_reg
        if (!wr_arst_n) begin
            wr_full <= 1'b0;
        end else begin
            wr_full <= wr_full_next;
        end
    end : full_reg

    // =========================================================================
    // Overflow Detection
    //
    // Overflow: upstream asserts wr_en when FIFO is already full.
    // This is a protocol violation from the upstream perspective.
    // The overflow indicator is a registered sticky flag that informs
    // debug/monitoring logic. It does NOT cause data corruption —
    // wr_en_qual is already gated by ~wr_full, so memory is protected.
    //
    // Reset: clears overflow indicator.
    // Silicon bring-up: overflow is routed to a status register for debug.
    // =========================================================================
    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : overflow_reg
        if (!wr_arst_n) begin
            wr_overflow <= 1'b0;
        end else begin
            // Overflow: write requested while full
            wr_overflow <= wr_en & wr_full;
        end
    end : overflow_reg

    // =========================================================================
    // Synchronizer Instantiation: rd_gray → wr_clk domain
    //
    // The read Gray pointer (from rd_ptr_ctrl, clocked on rd_clk) must be
    // synchronized into the write domain before it can be used in the full
    // detection logic.
    //
    // sync_2ff takes rd_gray (source: rd domain) and produces rd_gray_sync
    // (destination: wr domain).
    //
    // NOTE: rd_gray is an INPUT to this module (port rd_gray_sync).
    //       The sync_2ff is instantiated in async_fifo_top.sv and its output
    //       is connected here. This keeps wr_ptr_ctrl self-contained and
    //       allows the CDC crossing to be visible at the top level for
    //       CDC tool annotation.
    // =========================================================================
    // (Synchronizer instantiated at async_fifo_top level — see top-level comments)

    // =========================================================================
    // Parameter Validation
    // =========================================================================
    // synthesis translate_off
    initial begin : param_check
        if (FIFO_DEPTH < 4) begin
            $error("[wr_ptr_ctrl] FIFO_DEPTH=%0d must be >= 4. PTR_WIDTH must be >= 3 to avoid zero-width slice in full_detect.",
                   FIFO_DEPTH);
            $finish;
        end
        if (PTR_WIDTH != ADDR_WIDTH + 1) begin
            $error("[wr_ptr_ctrl] PTR_WIDTH=%0d must equal ADDR_WIDTH+1=%0d.",
                   PTR_WIDTH, ADDR_WIDTH + 1);
            $finish;
        end
        if (ADDR_WIDTH != $clog2(FIFO_DEPTH)) begin
            $error("[wr_ptr_ctrl] ADDR_WIDTH=%0d != $clog2(FIFO_DEPTH=%0d)=%0d.",
                   ADDR_WIDTH, FIFO_DEPTH, $clog2(FIFO_DEPTH));
            $finish;
        end
    end : param_check
    // synthesis translate_on

endmodule : wr_ptr_ctrl

`endif // WR_PTR_CTRL_SV
