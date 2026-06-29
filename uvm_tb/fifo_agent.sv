
`ifndef FIFO_AGENT_SV
`define FIFO_AGENT_SV

class fifo_agent extends uvm_agent;
    `uvm_component_utils(fifo_agent)

    fifo_sequencer  sequencer;
    fifo_driver     driver;
    fifo_monitor    monitor;

    uvm_analysis_port #(fifo_wr_obs) wr_ap;
    uvm_analysis_port #(fifo_rd_obs) rd_ap;

    function new(string name = "fifo_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        monitor = fifo_monitor::type_id::create("monitor", this);

        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = fifo_sequencer::type_id::create("sequencer", this);
            driver    = fifo_driver::type_id::create("driver", this);
        end

        wr_ap = new("wr_ap", this);
        rd_ap = new("rd_ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end

        monitor.wr_ap.connect(wr_ap);
        monitor.rd_ap.connect(rd_ap);
    endfunction

endclass : fifo_agent

`endif

