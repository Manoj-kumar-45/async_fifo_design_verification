//interface 

interface fifo_if #(
    parameter int DATA_WIDTH = 8
)(
    input logic wr_clk,   // both clocks come IN -- TB top generates them
    input logic rd_clk
);



    // Write domain
    logic                  wr_rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  wr_full;    // DUT output, driver reads this

    // Read domain
    logic                  rd_rst_n;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;    // DUT output, monitor reads this
    logic                  rd_empty;   // DUT output, driver reads this


    clocking wr_cb @(posedge wr_clk);
        default input #1step output #1;
        output wr_en;
        output wr_data;
        input  wr_full;    // read-back: driver checks before writing
    endclocking


    clocking rd_cb @(posedge rd_clk);
        default input #1step output #1;
        output rd_en;
        input  rd_data;    // DUT output: data read out
        input  rd_empty;   // read-back: driver checks before reading
    endclocking

    //------------------------------------------------------------------
    // MODPORT 1 of 2 : DRIVER
    // Groups both clocking blocks + the raw rst_n signals (reset is
    // driven outside the clocking block because it's async-assert,
    // not synchronous to either clock).
    //------------------------------------------------------------------
    modport DRIVER (
        clocking wr_cb,
        clocking rd_cb,
        output   wr_rst_n,
        output   rd_rst_n
    );

    //------------------------------------------------------------------
    // MODPORT 2 of 2 : MONITOR
    // Monitor is read-only -- it never drives anything, so it only
    // needs the sampling (input) view of both clock domains.
    //------------------------------------------------------------------
    clocking wr_mon_cb @(posedge wr_clk);
        default input #1step;
        input wr_en;
        input wr_data;
        input wr_full;
        input wr_rst_n;
    endclocking

    clocking rd_mon_cb @(posedge rd_clk);
        default input #1step;
        input rd_en;
        input rd_data;
        input rd_empty;
        input rd_rst_n;
    endclocking

    modport MONITOR (
        clocking wr_mon_cb,
        clocking rd_mon_cb
    );

endinterface : fifo_if