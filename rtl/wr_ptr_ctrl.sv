`ifndef WR_PTR_CTRL_SV
`define WR_PTR_CTRL_SV

`include "sync_2FF.sv"

module wr_ptr_ctrl #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4,
    parameter int unsigned PTR_WIDTH  = 5
) (
    input  logic                  wr_clk,
    input  logic                  wr_arst_n,
    input  logic                  wr_en,
    input  logic [PTR_WIDTH-1:0]  rd_gray_sync,

    output logic [ADDR_WIDTH-1:0] wr_addr,
    output logic                  wr_en_qual,

    output logic [PTR_WIDTH-1:0]  wr_gray,

    output logic                  wr_full,
    output logic                  wr_overflow
);

    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] wr_ptr_bin_next;
    logic [PTR_WIDTH-1:0] wr_gray_next;
    logic                 wr_full_next;

    assign wr_en_qual = wr_en & ~wr_full;

    always_comb begin
        if (wr_en_qual)
            wr_ptr_bin_next = wr_ptr_bin + 1;
        else
            wr_ptr_bin_next = wr_ptr_bin;
    end

    always_comb begin : bin_to_gray_next
        wr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);
    end : bin_to_gray_next

    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : wr_ptr_reg
        if (!wr_arst_n) begin
            wr_ptr_bin <= {PTR_WIDTH{1'b0}};
            wr_gray    <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_ptr_bin <= wr_ptr_bin_next;
            wr_gray    <= wr_gray_next;
        end
    end : wr_ptr_reg

    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

    localparam int unsigned LOWER_WIDTH = PTR_WIDTH - 2;

    always_comb begin : full_detect
        wr_full_next =
            (wr_gray_next[PTR_WIDTH-1]     != rd_gray_sync[PTR_WIDTH-1]) &&
            (wr_gray_next[PTR_WIDTH-2]     != rd_gray_sync[PTR_WIDTH-2]) &&
            (wr_gray_next[LOWER_WIDTH-1:0] == rd_gray_sync[LOWER_WIDTH-1:0]);
    end : full_detect

    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : full_reg
        if (!wr_arst_n) begin
            wr_full <= 1'b0;
        end else begin
            wr_full <= wr_full_next;
        end
    end : full_reg

    always_ff @(posedge wr_clk or negedge wr_arst_n) begin : overflow_reg
        if (!wr_arst_n) begin
            wr_overflow <= 1'b0;
        end else begin
            wr_overflow <= wr_en & wr_full;
        end
    end : overflow_reg

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

`endif