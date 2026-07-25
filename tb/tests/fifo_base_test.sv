`ifndef FIFO_BASE_TEST_SV
`define FIFO_BASE_TEST_SV

class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)

    fifo_env env;

    int unsigned fifo_depth = 16;
    int unsigned data_width = 8;

    function new(string name = "fifo_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'($value$plusargs("FIFO_DEPTH=%0d", fifo_depth));
        void'($value$plusargs("DATA_WIDTH=%0d", data_width));

        uvm_config_db #(int unsigned)::set(
            this, "*", "fifo_depth", fifo_depth);

        uvm_config_db #(int unsigned)::set(
            this, "*", "data_width", data_width);

        env = fifo_env::type_id::create("env", this);

        `uvm_info("TEST",
            $sformatf("fifo_base_test build: depth=%0d width=%0d",
            fifo_depth, data_width),
            UVM_LOW)
    endfunction

    task do_reset();
        fifo_reset_vseq rst;

        rst = fifo_reset_vseq::type_id::create("rst");
        rst.start(env.vseqr);
    endtask

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info("TEST", "=== UVM TOPOLOGY ===", UVM_MEDIUM)
        uvm_top.print_topology();
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;

        super.report_phase(phase);

        svr = uvm_report_server::get_server();

        `uvm_info("TEST",
                  "==========================================",
                  UVM_NONE)

        if (svr.get_severity_count(UVM_ERROR) == 0 &&
            svr.get_severity_count(UVM_FATAL) == 0) begin

            `uvm_info("TEST",
                      "         OVERALL RESULT : PASS            ",
                      UVM_NONE)

        end
        else begin

            `uvm_info("TEST",
                      "         OVERALL RESULT : FAIL            ",
                      UVM_NONE)

            `uvm_info("TEST",
                $sformatf("  Errors: %0d  Fatals: %0d",
                    svr.get_severity_count(UVM_ERROR),
                    svr.get_severity_count(UVM_FATAL)),
                UVM_NONE)
        end

        `uvm_info("TEST",
                  "==========================================",
                  UVM_NONE)
    endfunction

endclass : fifo_base_test

`endif