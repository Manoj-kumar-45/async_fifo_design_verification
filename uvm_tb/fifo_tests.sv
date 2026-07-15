`ifndef FIFO_DIRECTED_TESTS_SV
`define FIFO_DIRECTED_TESTS_SV

class reset_test extends fifo_base_test;
`uvm_component_utils(reset_test)

    function new(string name = "reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_reset_vseq rst;
        phase.raise_objection(this);

        `uvm_info("TEST", "reset_test: running double reset", UVM_LOW)

        do_reset();

        rst = fifo_reset_vseq::type_id::create("rst");
        rst.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : reset_test

class single_write_read_test extends fifo_base_test;
`uvm_component_utils(single_write_read_test)

    function new(string name = "single_write_read_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_single_wr_rd_vseq seq;
        phase.raise_objection(this);

        do_reset();

        seq = fifo_single_wr_rd_vseq::type_id::create("seq");
        seq.test_data = 8'hA5;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : single_write_read_test

class full_flag_test extends fifo_base_test;
`uvm_component_utils(full_flag_test)

    function new(string name = "full_flag_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_multi_write_vseq seq;
        phase.raise_objection(this);

        do_reset();

        seq = fifo_multi_write_vseq::type_id::create("seq");
        seq.num_writes = fifo_depth + 4;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : full_flag_test

class empty_flag_test extends fifo_base_test;
`uvm_component_utils(empty_flag_test)

    function new(string name = "empty_flag_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_multi_write_vseq wseq;
        fifo_multi_read_vseq  rseq;
        phase.raise_objection(this);

        do_reset();

        wseq = fifo_multi_write_vseq::type_id::create("wseq");
        wseq.num_writes = fifo_depth / 2;
        wseq.start(env.vseqr);

        repeat (8) begin
            @(posedge env.agent.monitor.vif.rd_clk);
        end

        rseq = fifo_multi_read_vseq::type_id::create("rseq");
        rseq.num_reads = fifo_depth;
        rseq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : empty_flag_test

class back_to_back_write_test extends fifo_base_test;
`uvm_component_utils(back_to_back_write_test)

    function new(string name = "back_to_back_write_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_multi_write_vseq seq;
        phase.raise_objection(this);

        do_reset();

        seq = fifo_multi_write_vseq::type_id::create("seq");
        seq.num_writes = fifo_depth * 3;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : back_to_back_write_test

class back_to_back_read_test extends fifo_base_test;
`uvm_component_utils(back_to_back_read_test)

    function new(string name = "back_to_back_read_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_multi_write_vseq wseq;
        fifo_multi_read_vseq  rseq;
        phase.raise_objection(this);

        do_reset();

        wseq = fifo_multi_write_vseq::type_id::create("wseq");
        wseq.num_writes = fifo_depth;
        wseq.start(env.vseqr);

        repeat (8) @(posedge env.agent.monitor.vif.rd_clk);

        rseq = fifo_multi_read_vseq::type_id::create("rseq");
        rseq.num_reads = fifo_depth * 3;
        rseq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : back_to_back_read_test

class pointer_wraparound_test extends fifo_base_test;
`uvm_component_utils(pointer_wraparound_test)

    function new(string name = "pointer_wraparound_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_wraparound_vseq seq;
        phase.raise_objection(this);

        do_reset();

        seq = fifo_wraparound_vseq::type_id::create("seq");
        seq.fifo_depth = fifo_depth;
        seq.num_wraps  = 6;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : pointer_wraparound_test

class write_when_full_attempt_test extends fifo_base_test;
`uvm_component_utils(write_when_full_attempt_test)

    function new(string name = "write_when_full_attempt_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        do_reset();

        begin
            fifo_multi_write_vseq wseq;
            wseq = fifo_multi_write_vseq::type_id::create("wseq");
            wseq.num_writes = fifo_depth;
            wseq.start(env.vseqr);
        end

        repeat (6) @(posedge env.agent.monitor.vif.wr_clk);

        repeat (8) begin
            fifo_seq_item txn;
            txn = fifo_seq_item::type_id::create("txn");
            start_item(txn);
            void'(txn.randomize() with {
                wr_en == 1'b1;
                rd_en == 1'b0;
            });
            finish_item(txn);
        end

        phase.drop_objection(this);
    endtask

endclass : write_when_full_attempt_test

class read_when_empty_attempt_test extends fifo_base_test;
`uvm_component_utils(read_when_empty_attempt_test)

    function new(string name = "read_when_empty_attempt_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        do_reset();

        repeat (10) begin
            fifo_seq_item txn;
            txn = fifo_seq_item::type_id::create("txn");
            start_item(txn);
            void'(txn.randomize() with {
                wr_en == 1'b0;
                rd_en == 1'b1;
            });
            finish_item(txn);
        end

        phase.drop_objection(this);
    endtask

endclass : read_when_empty_attempt_test

class reset_during_active_transfer_test extends fifo_base_test;
`uvm_component_utils(reset_during_active_transfer_test)

    function new(string name = "reset_during_active_transfer_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_reset_during_xfer_vseq seq;
        phase.raise_objection(this);

        do_reset();

        seq = fifo_reset_during_xfer_vseq::type_id::create("seq");
        seq.start(env.vseqr);

        do_reset();

        begin
            fifo_single_wr_rd_vseq check;
            check = fifo_single_wr_rd_vseq::type_id::create("check");
            check.test_data = 8'hCC;
            check.start(env.vseqr);
        end

        phase.drop_objection(this);
    endtask

endclass : reset_during_active_transfer_test

`endif
