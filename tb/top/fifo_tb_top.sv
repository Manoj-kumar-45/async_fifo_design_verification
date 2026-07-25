`timescale 1ns/1ps

module fifo_tb_top;

    import uvm_pkg::*;
    import fifo_tb_pkg::*;
    `include "uvm_macros.svh"

    real wr_clk_period = 3.0;
    real rd_clk_period = 7.0;

    bit wr_clk = 0;
    bit rd_clk = 0;

    initial begin
        void'($value$plusargs("WR_CLK_PERIOD=%f", wr_clk_period));
        void'($value$plusargs("RD_CLK_PERIOD=%f", rd_clk_period));
    end

    always #(wr_clk_period / 2.0) wr_clk = ~wr_clk;
    always #(rd_clk_period / 2.0) rd_clk = ~rd_clk;

    fifo_if #(.DATA_WIDTH(8)) dut_if (
        .wr_clk (wr_clk),
        .rd_clk (rd_clk)
    );

    initial begin
        dut_if.wr_rst_n = 1'b0;
        dut_if.rd_rst_n = 1'b0;
        dut_if.wr_en    = 1'b0;
        dut_if.wr_data  = '0;
        dut_if.rd_en    = 1'b0;
    end

    async_fifo_top #(
        .DATA_WIDTH (8),
        .FIFO_DEPTH (16)
    ) u_dut (
        .wr_clk   (dut_if.wr_clk),
        .wr_rst_n (dut_if.wr_rst_n),
        .wr_en    (dut_if.wr_en),
        .wr_data  (dut_if.wr_data),
        .wr_full  (dut_if.wr_full),
        .rd_clk   (dut_if.rd_clk),
        .rd_rst_n (dut_if.rd_rst_n),
        .rd_en    (dut_if.rd_en),
        .rd_data  (dut_if.rd_data),
        .rd_empty (dut_if.rd_empty)
    );

    initial begin
        uvm_config_db #(virtual fifo_if.DRIVER)::set(
            null,
            "uvm_test_top.env.agent.driver",
            "fifo_vif",
            dut_if);

        uvm_config_db #(virtual fifo_if.MONITOR)::set(
            null,
            "uvm_test_top.env.agent.monitor",
            "fifo_vif",
            dut_if);

        uvm_config_db #(virtual fifo_if)::set(
            null,
            "*",
            "fifo_vif_raw",
            dut_if);

        run_test();
    end

    initial begin
        if ($test$plusargs("DUMP")) begin
            $shm_open("fifo_waves.shm");
            $shm_probe(fifo_tb_top, "ACTMF");
        end
    end

endmodule : fifo_tb_top