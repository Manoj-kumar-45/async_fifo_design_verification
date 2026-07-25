`ifndef FIFO_DRIVER_SV
`define FIFO_DRIVER_SV

class fifo_driver extends uvm_driver #(fifo_seq_item);

    `uvm_component_utils(fifo_driver)

    virtual fifo_if.DRIVER vif;

    mailbox #(fifo_seq_item) mb_to_rd;

    event rd_side_done;

    function new(string name = "fifo_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual fifo_if.DRIVER)::get(
                this,
                "",
                "fifo_vif",
                vif))
            `uvm_fatal("DRV/CFG",
                "virtual fifo_if.DRIVER not found in config_db. Check tb_top sets it before run_test()")

        mb_to_rd = new(1);

    endfunction


    task run_phase(uvm_phase phase);

        _drive_idle();

        wait (vif.wr_rst_n === 1'b1 &&
              vif.rd_rst_n === 1'b1);

        `uvm_info("DRV",
                  "Both resets released — starting stimulus",
                  UVM_LOW)

        fork
            _wr_thread();
            _rd_thread();
        join

    endtask

    task _wr_thread();

        forever begin

            fifo_seq_item txn;

            seq_item_port.get_next_item(txn);

            `uvm_info("DRV",
                      {"WR_THREAD got: ", txn.convert2string()},
                      UVM_HIGH)

            mb_to_rd.put(txn);

            if (txn.wr_idle_cycles > 0) begin

                vif.wr_cb.wr_en   <= 1'b0;
                vif.wr_cb.wr_data <= '0;

                repeat (txn.wr_idle_cycles)
                    @(vif.wr_cb);

            end

            if (txn.wr_en) begin

                if (vif.wr_cb.wr_full) begin

                    `uvm_info("DRV",
                              "WR stalled — wr_full asserted",
                              UVM_HIGH)

                    vif.wr_cb.wr_en <= 1'b0;

                    @(vif.wr_cb);

                    while (vif.wr_cb.wr_full)
                        @(vif.wr_cb);

                end

                vif.wr_cb.wr_en   <= 1'b1;
                vif.wr_cb.wr_data <= txn.wr_data;

                @(vif.wr_cb);

                vif.wr_cb.wr_en   <= 1'b0;
                vif.wr_cb.wr_data <= '0;

            end
            else begin

                vif.wr_cb.wr_en   <= 1'b0;
                vif.wr_cb.wr_data <= '0;

                @(vif.wr_cb);

            end

            @rd_side_done;

            seq_item_port.item_done();

            `uvm_info("DRV",
                      "item_done() called — transaction complete",
                      UVM_HIGH)

        end

    endtask

    task _rd_thread();

        forever begin

            fifo_seq_item txn;

            mb_to_rd.get(txn);

            `uvm_info("DRV",
                      {"RD_THREAD got: ", txn.convert2string()},
                      UVM_HIGH)

            if (txn.rd_idle_cycles > 0) begin

                vif.rd_cb.rd_en <= 1'b0;

                repeat (txn.rd_idle_cycles)
                    @(vif.rd_cb);

            end

            if (txn.rd_en) begin

                if (vif.rd_cb.rd_empty) begin

                    `uvm_info("DRV",
                              "RD stalled — rd_empty asserted",
                              UVM_HIGH)

                    vif.rd_cb.rd_en <= 1'b0;

                    @(vif.rd_cb);

                    while (vif.rd_cb.rd_empty)
                        @(vif.rd_cb);

                end

                vif.rd_cb.rd_en <= 1'b1;

                @(vif.rd_cb);

                vif.rd_cb.rd_en <= 1'b0;

            end
            else begin

                vif.rd_cb.rd_en <= 1'b0;

                @(vif.rd_cb);

            end

            -> rd_side_done;

            `uvm_info("DRV",
                      "RD_THREAD complete",
                      UVM_HIGH)

        end

    endtask


    task _drive_idle();

        vif.wr_cb.wr_en   <= 1'b0;
        vif.wr_cb.wr_data <= '0;

        vif.rd_cb.rd_en   <= 1'b0;

    endtask

endclass

`endif