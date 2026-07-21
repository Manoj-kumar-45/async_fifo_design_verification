`ifndef FIFO_ASSERTIONS_SV
`define FIFO_ASSERTIONS_SV

module fifo_assertions #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_DEPTH = 16
)(
    input logic                  wr_clk,
    input logic                  wr_rst_n,
    input logic                  wr_en,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic                  wr_full,
    input logic                  rd_clk,
    input logic                  rd_rst_n,
    input logic                  rd_en,
    input logic [DATA_WIDTH-1:0] rd_data,
    input logic                  rd_empty
);

    localparam int PTR_W = $clog2(FIFO_DEPTH) + 1;

    wire [PTR_W-1:0] wr_ptr_gray = u_wr_ptr_ctrl.wr_ptr_gray;
    wire [PTR_W-1:0] rd_ptr_gray = u_rd_ptr_ctrl.rd_ptr_gray;

    logic [PTR_W-1:0] wr_ptr_gray_q;
    logic [PTR_W-1:0] rd_ptr_gray_q;

    always_ff @(posedge wr_clk or negedge wr_rst_n)
        if (!wr_rst_n) wr_ptr_gray_q <= '0;
        else           wr_ptr_gray_q <= wr_ptr_gray;

    always_ff @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) rd_ptr_gray_q <= '0;
        else           rd_ptr_gray_q <= rd_ptr_gray;

    function automatic int f_popcount(logic [PTR_W-1:0] a, b);
        logic [PTR_W-1:0] diff;
        int cnt;
        diff = a ^ b;
        cnt  = 0;
        for (int i = 0; i < PTR_W; i++) cnt += diff[i];
        return cnt;
    endfunction

    a_no_wr_when_full: assert property (
        @(posedge wr_clk) disable iff (!wr_rst_n)
        wr_full |-> (wr_ptr_gray == wr_ptr_gray_q)
    ) else $error("[ASSERT FAIL] a_no_wr_when_full: wr_ptr advanced while wr_full=1 at t=%0t", $time);

    a_no_rd_when_empty: assert property (
        @(posedge rd_clk) disable iff (!rd_rst_n)
        rd_empty |-> (rd_ptr_gray == rd_ptr_gray_q)
    ) else $error("[ASSERT FAIL] a_no_rd_when_empty: rd_ptr advanced while rd_empty=1 at t=%0t", $time);

    a_full_empty_mutex: assert property (
        @(posedge wr_clk) disable iff (!wr_rst_n)
        !(wr_full && rd_empty)
    ) else $warning("[ASSERT WARN] a_full_empty_mutex: wr_full && rd_empty both high at t=%0t", $time);

    a_wr_gray_one_bit: assert property (
        @(posedge wr_clk) disable iff (!wr_rst_n)
        f_popcount(wr_ptr_gray, wr_ptr_gray_q) <= 1
    ) else $error("[ASSERT FAIL] a_wr_gray_one_bit: wr_ptr_gray changed by >1 bit at t=%0t", $time);

    a_rd_gray_one_bit: assert property (
        @(posedge rd_clk) disable iff (!rd_rst_n)
        f_popcount(rd_ptr_gray, rd_ptr_gray_q) <= 1
    ) else $error("[ASSERT FAIL] a_rd_gray_one_bit: rd_ptr_gray changed by >1 bit at t=%0t", $time);

    a_wr_ptr_reset: assert property (
        @(posedge wr_clk)
        $fell(wr_rst_n) |=> (wr_ptr_gray == '0)
    ) else $error("[ASSERT FAIL] a_wr_ptr_reset: wr_ptr not 0 after reset at t=%0t", $time);

    a_rd_ptr_reset: assert property (
        @(posedge rd_clk)
        $fell(rd_rst_n) |=> (rd_ptr_gray == '0)
    ) else $error("[ASSERT FAIL] a_rd_ptr_reset: rd_ptr not 0 after reset at t=%0t", $time);

endmodule : fifo_assertions

bind async_fifo_top fifo_assertions #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
) u_fifo_assertions (
    .wr_clk   (wr_clk),
    .wr_rst_n (wr_rst_n),
    .wr_en    (wr_en),
    .wr_data  (wr_data),
    .wr_full  (wr_full),
    .rd_clk   (rd_clk),
    .rd_rst_n (rd_rst_n),
    .rd_en    (rd_en),
    .rd_data  (rd_data),
    .rd_empty (rd_empty)
);

`endif