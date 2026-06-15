// Code your testbench here
// or browse Examples
`ifndef SYNC_2FF_SV
`define SYNC_2FF_SV

module sync_2ff #(
    parameter int unsigned PTR_WIDTH = 5
) (
    input  logic                  clk,
    input  logic                  arst_n,
    input  logic [PTR_WIDTH-1:0]  d,
    output logic [PTR_WIDTH-1:0]  q
);

    logic [PTR_WIDTH-1:0] sync_ff1;
    logic [PTR_WIDTH-1:0] sync_ff2;

    always_ff @(posedge clk or negedge arst_n) begin : sync_stages
        if (!arst_n) begin
            sync_ff1 <= {PTR_WIDTH{1'b0}};
            sync_ff2 <= {PTR_WIDTH{1'b0}};
        end else begin
            sync_ff1 <= d;
            sync_ff2 <= sync_ff1;
        end
    end : sync_stages

    assign q = sync_ff2;

    // synthesis translate_off
    initial begin : param_check
        if (PTR_WIDTH < 2) begin
            $error("[sync_2ff] PTR_WIDTH=%0d is invalid. Minimum value is 2.",
                   PTR_WIDTH);
            $finish;
        end
    end : param_check
    // synthesis translate_on

endmodule : sync_2ff

`endif