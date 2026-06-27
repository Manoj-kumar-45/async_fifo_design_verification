`ifndef FIFO_MONITOR_SV
`define FIFO_MONITOR_SV

class fifo_wr_obs extends uvm_sequence_item;

    bit [7:0]  wr_data;
    bit        wr_en;
    bit        wr_full;
    bit        wr_rst_n;
    time       timestamp;

    `uvm_object_utils_begin(fifo_wr_obs)
        `uvm_field_int(wr_data,    UVM_ALL_ON)
        `uvm_field_int(wr_en,      UVM_ALL_ON)
        `uvm_field_int(wr_full,    UVM_ALL_ON)
        `uvm_field_int(wr_rst_n,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_wr_obs");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "[WR_OBS @%0t] wr_en=%0b wr_data=0x%02h wr_full=%0b wr_rst_n=%0b",
            timestamp, wr_en, wr_data, wr_full, wr_rst_n);
    endfunction

endclass : fifo_wr_obs


class fifo_rd_obs extends uvm_sequence_item;

    bit [7:0]  rd_data;
    bit        rd_en;
    bit        rd_empty;
    bit        rd_rst_n;
    time       timestamp;

    `uvm_object_utils_begin(fifo_rd_obs)
        `uvm_field_int(rd_data,    UVM_ALL_ON)
        `uvm_field_int(rd_en,      UVM_ALL_ON)
        `uvm_field_int(rd_empty,   UVM_ALL_ON)
        `uvm_field_int(rd_rst_n,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_rd_obs");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "[RD_OBS @%0t] rd_en=%0b rd_data=0x%02h rd_empty=%0b rd_rst_n=%0b",
            timestamp, rd_en, rd_data, rd_empty, rd_rst_n);
    endfunction

endclass : fifo_rd_obs


class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)

    virtual fifo_if.MONITOR vif;

    uvm_analysis_port #(fifo_wr_obs) wr_ap;
    uvm_analysis_port #(fifo_rd_obs) rd_ap;

    function new(string name = "fifo_monitor", uvm_component parent = null);
        super.new(name, parent);
        wr_ap = new("wr_ap", this);
        rd_ap = new("rd_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual fifo_if.MONITOR)::get(
                this, "", "fifo_vif", vif))
            `uvm_fatal("MON/CFG",
                "virtual fifo_if.MONITOR not found in config_db. \
                 Check tb_top sets it before run_test()")
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("MON", "Monitor starting — forking two sampling threads", UVM_LOW)
        fork
            _sample_wr_domain();
            _sample_rd_domain();
        join_none
    endtask

    task _sample_wr_domain();
        forever begin
            @(vif.wr_mon_cb);

            begin
                fifo_wr_obs obs;
                obs = fifo_wr_obs::type_id::create("wr_obs");

                obs.wr_en     = vif.wr_mon_cb.wr_en;
                obs.wr_data   = vif.wr_mon_cb.wr_data;
                obs.wr_full   = vif.wr_mon_cb.wr_full;
                obs.wr_rst_n  = vif.wr_mon_cb.wr_rst_n;
                obs.timestamp = $time;

                wr_ap.write(obs);

                `uvm_info("MON", obs.convert2string(), UVM_FULL)
            end
        end
    endtask

    task _sample_rd_domain();
        forever begin
            @(vif.rd_mon_cb);

            begin
                fifo_rd_obs obs;
                obs = fifo_rd_obs::type_id::create("rd_obs");

                obs.rd_en     = vif.rd_mon_cb.rd_en;
                obs.rd_data   = vif.rd_mon_cb.rd_data;
                obs.rd_empty  = vif.rd_mon_cb.rd_empty;
                obs.rd_rst_n  = vif.rd_mon_cb.rd_rst_n;
                obs.timestamp = $time;

                rd_ap.write(obs);

                `uvm_info("MON", obs.convert2string(), UVM_FULL)
            end
        end
    endtask

endclass : fifo_monitor

`endif