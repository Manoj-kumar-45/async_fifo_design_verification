

`ifndef FIFO_VIRTUAL_SEQUENCES_SV
`define FIFO_VIRTUAL_SEQUENCES_SV



class fifo_base_vseq extends uvm_sequence;
    `uvm_object_utils(fifo_base_vseq)
    `uvm_declare_p_sequencer(fifo_virtual_sequencer)


    virtual fifo_if vif;

    int unsigned fifo_depth = 16;

    function new(string name = "fifo_base_vseq");
        super.new(name);
    endfunction


    task pre_body();
        if (!uvm_config_db #(virtual fifo_if)::get(
                null, "", "fifo_vif_raw", vif))
            `uvm_fatal("VSEQ", "fifo_if raw handle not found in config_db")

        void'(uvm_config_db #(int unsigned)::get(
                null, "*", "fifo_depth", fifo_depth));
    endtask


    task do_reset(int unsigned wr_hold = 8, int unsigned rd_hold = 8);
        vif.wr_rst_n = 1'b0;
        vif.rd_rst_n = 1'b0;
        repeat (wr_hold) @(posedge vif.wr_clk);
        vif.wr_rst_n = 1'b1;
        repeat (3) @(posedge vif.rd_clk);
        vif.rd_rst_n = 1'b1;

        repeat (4) @(posedge vif.wr_clk);
        `uvm_info("VSEQ", "Reset complete — both domains active", UVM_LOW)
    endtask

endclass : fifo_base_vseq


class fifo_reset_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_reset_vseq)

    function new(string name = "fifo_reset_vseq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("VSEQ", "fifo_reset_vseq: asserting reset", UVM_LOW)
        do_reset(10, 10);
    endtask

endclass : fifo_reset_vseq


class fifo_single_wr_rd_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_single_wr_rd_vseq)

    rand bit [7:0] test_data;

    function new(string name = "fifo_single_wr_rd_vseq");
        super.new(name);
    endfunction

    task body();
        fifo_write_seq wseq;
        fifo_read_seq  rseq;

        if (!this.randomize())
            `uvm_fatal("VSEQ", "randomize failed")

        `uvm_info("VSEQ",
            $sformatf("fifo_single_wr_rd_vseq: data=0x%02h", test_data),
            UVM_LOW)


        wseq = fifo_write_seq::type_id::create("wseq");
        wseq.write_data = test_data;
        wseq.start(p_sequencer.fifo_seqr);



        repeat (6) @(posedge vif.rd_clk);


        rseq = fifo_read_seq::type_id::create("rseq");
        rseq.start(p_sequencer.fifo_seqr);

    endtask

endclass : fifo_single_wr_rd_vseq






class fifo_multi_write_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_multi_write_vseq)

    int unsigned num_writes = 16;

    function new(string name = "fifo_multi_write_vseq");
        super.new(name);
    endfunction

    task body();
        fifo_burst_write_seq wseq;

        `uvm_info("VSEQ",
            $sformatf("fifo_multi_write_vseq: %0d writes", num_writes),
            UVM_LOW)

        wseq = fifo_burst_write_seq::type_id::create("wseq");
        wseq.num_writes = num_writes;
        wseq.start(p_sequencer.fifo_seqr);

    endtask

endclass : fifo_multi_write_vseq


class fifo_multi_read_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_multi_read_vseq)

    int unsigned num_reads = 16;

    function new(string name = "fifo_multi_read_vseq");
        super.new(name);
    endfunction

    task body();
        fifo_burst_read_seq rseq;

        `uvm_info("VSEQ",
            $sformatf("fifo_multi_read_vseq: %0d reads", num_reads),
            UVM_LOW)

        rseq = fifo_burst_read_seq::type_id::create("rseq");
        rseq.num_reads = num_reads;
        rseq.start(p_sequencer.fifo_seqr);

    endtask

endclass : fifo_multi_read_vseq



class fifo_simul_wr_rd_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_simul_wr_rd_vseq)

    int unsigned num_txns = 50;

    function new(string name = "fifo_simul_wr_rd_vseq");
        super.new(name);
    endfunction

    task body();

        begin
            fifo_write_seq pre;
            pre = fifo_write_seq::type_id::create("pre");
            pre.write_data = 8'hAB;
            pre.start(p_sequencer.fifo_seqr);
            repeat (6) @(posedge vif.rd_clk);
        end

        repeat (num_txns) begin
            fifo_seq_item txn;
            txn = fifo_seq_item::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize() with {
                wr_en == 1'b1;
                rd_en == 1'b1;
            })
                `uvm_fatal("VSEQ", "randomize failed")
            finish_item(txn);
        end

    endtask

endclass : fifo_simul_wr_rd_vseq






class fifo_random_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_random_vseq)

    int unsigned num_txns = 200;

    function new(string name = "fifo_random_vseq");
        super.new(name);
    endfunction

    task body();
        fifo_random_seq rseq;

        `uvm_info("VSEQ",
            $sformatf("fifo_random_vseq: %0d transactions", num_txns),
            UVM_LOW)

        rseq = fifo_random_seq::type_id::create("rseq");
        rseq.num_txns = num_txns;
        rseq.start(p_sequencer.fifo_seqr);

    endtask

endclass : fifo_random_vseq








class fifo_wraparound_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_wraparound_vseq)

    int unsigned num_wraps = 6;

    function new(string name = "fifo_wraparound_vseq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("VSEQ",
            $sformatf("fifo_wraparound_vseq: %0d fill/drain cycles", num_wraps),
            UVM_LOW)

        repeat (num_wraps) begin

            begin
                fifo_burst_write_seq wseq;
                wseq = fifo_burst_write_seq::type_id::create("wseq");
                wseq.num_writes = fifo_depth;
                wseq.start(p_sequencer.fifo_seqr);
            end

            repeat (8) @(posedge vif.rd_clk);

            begin
                fifo_burst_read_seq rseq;
                rseq = fifo_burst_read_seq::type_id::create("rseq");
                rseq.num_reads = fifo_depth;
                rseq.start(p_sequencer.fifo_seqr);
            end

            repeat (4) @(posedge vif.wr_clk);
        end

    endtask

endclass : fifo_wraparound_vseq



class fifo_reset_during_xfer_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_reset_during_xfer_vseq)

    function new(string name = "fifo_reset_during_xfer_vseq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("VSEQ", "fifo_reset_during_xfer_vseq: starting", UVM_LOW)

        fork

            begin
                fifo_burst_write_seq wseq;
                wseq = fifo_burst_write_seq::type_id::create("wseq");
                wseq.num_writes = fifo_depth * 2;
                wseq.start(p_sequencer.fifo_seqr);
            end

            begin

                repeat (10) @(posedge vif.wr_clk);
                `uvm_info("VSEQ", "Asserting wr_rst_n mid-burst", UVM_LOW)
                vif.wr_rst_n = 1'b0;
                repeat (5) @(posedge vif.wr_clk);
                vif.wr_rst_n = 1'b1;
                `uvm_info("VSEQ", "wr_rst_n released", UVM_LOW)
            end
        join


        repeat (10) @(posedge vif.wr_clk);

    endtask

endclass : fifo_reset_during_xfer_vseq

`endif