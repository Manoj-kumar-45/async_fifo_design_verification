`ifndef FIFO_RANDOM_TESTS_SV
`define FIFO_RANDOM_TESTS_SV

class random_test extends fifo_base_test;
    `uvm_component_utils(random_test)

    int unsigned num_txns = 300;

    function new(string name = "random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_random_vseq seq;
        phase.raise_objection(this);

        void'($value$plusargs("NUM_TXNS=%0d", num_txns));
        do_reset();

        seq = fifo_random_vseq::type_id::create("seq");
        seq.num_txns = num_txns;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : random_test


class random_full_throttle_test extends fifo_base_test;
    `uvm_component_utils(random_full_throttle_test)

    int unsigned num_txns = 500;

    function new(string name = "random_full_throttle_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_simul_wr_rd_vseq seq;
        phase.raise_objection(this);

        void'($value$plusargs("NUM_TXNS=%0d", num_txns));
        do_reset();

        seq = fifo_simul_wr_rd_vseq::type_id::create("seq");
        seq.num_txns = num_txns;
        seq.start(env.vseqr);

        phase.drop_objection(this);
    endtask

endclass : random_full_throttle_test


class random_burst_test extends fifo_base_test;
    `uvm_component_utils(random_burst_test)

    int unsigned num_bursts = 20;

    function new(string name = "random_burst_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        void'($value$plusargs("NUM_BURSTS=%0d", num_bursts));
        do_reset();

        repeat (num_bursts) begin
            int unsigned blen;
            blen = $urandom_range(1, fifo_depth);

            begin
                fifo_multi_write_vseq wseq;
                wseq = fifo_multi_write_vseq::type_id::create("wseq");
                wseq.num_writes = blen;
                wseq.start(env.vseqr);
            end

            repeat (6) @(posedge env.agent.monitor.vif.rd_clk);

            begin
                fifo_multi_read_vseq rseq;
                rseq = fifo_multi_read_vseq::type_id::create("rseq");
                rseq.num_reads = blen;
                rseq.start(env.vseqr);
            end
        end

        phase.drop_objection(this);
    endtask

endclass : random_burst_test

`endif