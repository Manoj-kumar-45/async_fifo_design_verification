// ```systemverilog
`ifndef ASYNC_FIFO_TOP_SV
`define ASYNC_FIFO_TOP_SV

`include "sync_2FF.sv"
`include "fifo_mem.sv"
`include "wr_ptr.sv"
`include "rd_ptr.sv"

module async_fifo_top #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH),
    parameter int unsigned PTR_WIDTH  = ADDR_WIDTH + 1
) (
    input  logic                  wr_clk,
    input  logic                  wr_arst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    output logic                  wr_full,
    output logic                  wr_overflow,

    input  logic                  rd_clk,
    input  logic                  rd_arst_n,
    input  logic                  rd_en,

    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_empty,
    output logic                  rd_underflow
);

    logic [ADDR_WIDTH-1:0] wr_addr;
    logic                  wr_en_qual;
    logic [PTR_WIDTH-1:0]  wr_gray;

    logic [ADDR_WIDTH-1:0] rd_addr;
    logic                  rd_en_qual;
    logic [PTR_WIDTH-1:0]  rd_gray;

    logic [PTR_WIDTH-1:0]  wr_gray_sync;
    logic [PTR_WIDTH-1:0]  rd_gray_sync;

    sync_2ff #(
        .PTR_WIDTH (PTR_WIDTH)
    ) u_sync_wr2rd (
        .clk    (rd_clk),
        .arst_n (rd_arst_n),
        .d      (wr_gray),
        .q      (wr_gray_sync)
    );

    sync_2ff #(
        .PTR_WIDTH (PTR_WIDTH)
    ) u_sync_rd2wr (
        .clk    (wr_clk),
        .arst_n (wr_arst_n),
        .d      (rd_gray),
        .q      (rd_gray_sync)
    );

    wr_ptr_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_wr_ptr_ctrl (
        .wr_clk      (wr_clk),
        .wr_arst_n   (wr_arst_n),
        .wr_en       (wr_en),
        .rd_gray_sync(rd_gray_sync),
        .wr_addr     (wr_addr),
        .wr_en_qual  (wr_en_qual),
        .wr_gray     (wr_gray),
        .wr_full     (wr_full),
        .wr_overflow (wr_overflow)
    );

    rd_ptr_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_rd_ptr_ctrl (
        .rd_clk      (rd_clk),
        .rd_arst_n   (rd_arst_n),
        .rd_en       (rd_en),
        .wr_gray_sync(wr_gray_sync),
        .rd_addr     (rd_addr),
        .rd_en_qual  (rd_en_qual),
        .rd_gray     (rd_gray),
        .rd_empty    (rd_empty),
        .rd_underflow(rd_underflow)
    );

    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_mem (
        .wr_clk  (wr_clk),
        .wr_en   (wr_en_qual),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (rd_clk),
        .rd_en   (rd_en_qual),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    property p_no_full_and_empty;
        @(posedge wr_clk) disable iff (!wr_arst_n)
        !(wr_full && rd_empty);
    endproperty

    property p_no_overflow;
        @(posedge wr_clk) disable iff (!wr_arst_n)
        !(wr_en && wr_full);
    endproperty

    property p_no_underflow;
        @(posedge rd_clk) disable iff (!rd_arst_n)
        !(rd_en && rd_empty);
    endproperty

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

endmodule : async_fifo_top

`endif

