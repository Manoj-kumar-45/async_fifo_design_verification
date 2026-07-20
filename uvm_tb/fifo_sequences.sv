//THE MAIN MOTIVE OF BASE CLASS TO ELIMINATE THE DUPLICATION

`ifndef FIFO_SEQUENCES_SV
`define FIFO_SEQUENCES_SV

class fifo_base_seq extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_base_seq)

    function new(string name = "fifo_base_seq");
        super.new(name);
    endfunction

    protected task send_item(
        bit                    do_write,
        bit                    do_read,
        bit [DATA_WIDTH-1:0]   data       = '0,
        bit                    rand_data  = 1,
        int                    wr_idle    = 0,
        int                    rd_idle    = 0
    );
        fifo_seq_item txn;

        txn = fifo_seq_item::type_id::create("txn");

        start_item(txn);

        if (rand_data) begin
            if (!txn.randomize() with {
                wr_en          == do_write;
                rd_en          == do_read;
                wr_idle_cycles == wr_idle;
                rd_idle_cycles == rd_idle;
            })
                `uvm_fatal("SEQ", "randomize() failed — check constraints")
        end
        else begin
            if (!txn.randomize() with {
                wr_en          == do_write;
                rd_en          == do_read;
                wr_data        == data;
                wr_idle_cycles == wr_idle;
                rd_idle_cycles == rd_idle;
            })
                `uvm_fatal("SEQ", "randomize() failed — check constraints")
        end

        `uvm_info("SEQ", txn.convert2string(), UVM_HIGH)

        finish_item(txn);

    endtask

endclass


class fifo_write_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_write_seq)

    rand bit [DATA_WIDTH-1:0] write_data;

    function new(string name = "fifo_write_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ",
                  $sformatf("fifo_write_seq: sending wr_data=0x%0h",
                            write_data),
                  UVM_LOW)

        send_item(
            .do_write (1),
            .do_read  (0),
            .data     (write_data),
            .rand_data(0)
        );
    endtask

endclass


class fifo_read_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_read_seq)

    function new(string name = "fifo_read_seq");
        super.new(name);
    endfunction

    task body();

        `uvm_info("SEQ",
                  "fifo_read_seq: sending rd_en",
                  UVM_LOW)

        send_item(
            .do_write(0),
            .do_read (1)
        );

    endtask

endclass


class fifo_burst_write_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_burst_write_seq)

    rand int unsigned num_writes;

    constraint c_num_writes {
        num_writes inside {[1:16]};
    }

    function new(string name = "fifo_burst_write_seq");
        super.new(name);
    endfunction

    task body();

        `uvm_info("SEQ",
                  $sformatf("fifo_burst_write_seq: %0d writes",
                            num_writes),
                  UVM_LOW)

        repeat (num_writes) begin
            send_item(
                .do_write (1),
                .do_read  (0),
                .rand_data(1),
                .wr_idle  (0)
            );
        end

    endtask

endclass

class fifo_burst_read_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_burst_read_seq)

    rand int unsigned num_reads;

    constraint c_num_reads {
        num_reads inside {[1:16]};
    }

    function new(string name = "fifo_burst_read_seq");
        super.new(name);
    endfunction

    task body();

        `uvm_info("SEQ",
                  $sformatf("fifo_burst_read_seq: %0d reads",
                            num_reads),
                  UVM_LOW)

        repeat (num_reads) begin
            send_item(
                .do_write(0),
                .do_read (1),
                .rd_idle (0)
            );
        end

    endtask

endclass


class fifo_random_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_random_seq)

    rand int unsigned num_txns;

    constraint c_num_txns {
        num_txns inside {[50:200]};
    }

    function new(string name = "fifo_random_seq");
        super.new(name);
    endfunction

    task body();

        `uvm_info("SEQ",
                  $sformatf("fifo_random_seq: %0d transactions",
                            num_txns),
                  UVM_LOW)

        repeat (num_txns) begin

            fifo_seq_item txn;

            txn = fifo_seq_item::type_id::create("txn");

            start_item(txn);

            if (!txn.randomize())
                `uvm_fatal("SEQ", "randomize() failed")

            `uvm_info("SEQ",
                      txn.convert2string(),
                      UVM_HIGH)

            finish_item(txn);

        end

    endtask

endclass


class fifo_write_then_read_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_write_then_read_seq)

    int unsigned depth = FIFO_DEPTH;

    function new(string name = "fifo_write_then_read_seq");
        super.new(name);
    endfunction

    task body();

        fifo_burst_write_seq wseq;
        fifo_burst_read_seq  rseq;

        `uvm_info("SEQ",
                  $sformatf("fifo_write_then_read_seq: depth=%0d",
                            depth),
                  UVM_LOW)

        wseq = fifo_burst_write_seq::type_id::create("wseq");
        wseq.num_writes = depth;
        wseq.start(m_sequencer);

        rseq = fifo_burst_read_seq::type_id::create("rseq");
        rseq.num_reads = depth;
        rseq.start(m_sequencer);

    endtask

endclass

`endif
  