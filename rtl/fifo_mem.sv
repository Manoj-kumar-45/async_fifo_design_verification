
`ifndef FIFO_MEM_SV
`define FIFO_MEM_SV

module fifo_mem #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4
) (
    input  logic                   wr_clk,
    input  logic                   wr_en,
    input  logic [ADDR_WIDTH-1:0]  wr_addr,
    input  logic [DATA_WIDTH-1:0]  wr_data,

    input  logic                   rd_clk,
    input  logic                   rd_en,
    input  logic [ADDR_WIDTH-1:0]  rd_addr,
    output logic [DATA_WIDTH-1:0]  rd_data
);

    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    always_ff @(posedge wr_clk) begin : write_port
        if (wr_en) begin
          mem[wr_addr] <= wr_data;
        end
    end : write_port

    always_ff @(posedge rd_clk) begin : read_port
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end : read_port

    initial begin : param_check
        if (FIFO_DEPTH < 2) begin
            $error("[fifo_mem] FIFO_DEPTH=%0d must be >= 2.", FIFO_DEPTH);
            $finish;
        end
        if ((FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) begin
            $error("[fifo_mem] FIFO_DEPTH=%0d must be a power of 2.", FIFO_DEPTH);
            $finish;
        end
        if (ADDR_WIDTH != $clog2(FIFO_DEPTH)) begin
            $error("[fifo_mem] ADDR_WIDTH=%0d does not match $clog2(FIFO_DEPTH=%0d)=%0d.",
                   ADDR_WIDTH, FIFO_DEPTH, $clog2(FIFO_DEPTH));
            $finish;
        end
    end : param_check

endmodule : fifo_mem

`endif

