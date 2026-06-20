`ifndef RD_PTR_CTRL_SV
`define RD_PTR_CTRL_SV

module rd_ptr_ctrl #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FIFO_DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4,
    parameter int unsigned PTR_WIDTH  = 5
) (
    input  logic                  rd_clk,
    input  logic                  rd_arst_n,
    input  logic                  rd_en,

    input  logic [PTR_WIDTH-1:0]  wr_gray_sync,


    output logic [ADDR_WIDTH-1:0] rd_addr,
    output logic                  rd_en_qual,
    output logic [PTR_WIDTH-1:0]  rd_gray,
    output logic                  rd_empty,
    output logic                  rd_underflow
);

    logic [PTR_WIDTH-1:0] rd_ptr_bin;//binary read pointer
    logic [PTR_WIDTH-1:0] rd_ptr_bin_next;
    logic [PTR_WIDTH-1:0] rd_gray_next;
    logic                 rd_empty_next;

    assign rd_en_qual = rd_en & ~rd_empty;

always_comb begin : next_bin_ptr
    if (rd_en_qual)
        rd_ptr_bin_next = rd_ptr_bin + 1'b1;
    else
        rd_ptr_bin_next = rd_ptr_bin;
end : next_bin_ptr

    always_comb begin : bin_to_gray_next
        rd_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);
    end : bin_to_gray_next

    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : rd_ptr_reg
        if (!rd_arst_n) begin
            rd_ptr_bin <= {PTR_WIDTH{1'b0}};
            rd_gray    <= {PTR_WIDTH{1'b0}};
        end
        else begin
            rd_ptr_bin <= rd_ptr_bin_next;
            rd_gray    <= rd_gray_next;
        end
    end : rd_ptr_reg

    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    always_comb begin : empty_detect
        rd_empty_next = (rd_gray_next == wr_gray_sync);
    end : empty_detect

    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : empty_reg
        if (!rd_arst_n)
            rd_empty <= 1'b1;
        else
            rd_empty <= rd_empty_next;
    end : empty_reg

    always_ff @(posedge rd_clk or negedge rd_arst_n) begin : underflow_reg
        if (!rd_arst_n)
            rd_underflow <= 1'b0;
        else
            rd_underflow <= rd_en & rd_empty;
    end : underflow_reg

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

endmodule : rd_ptr_ctrl

`endif