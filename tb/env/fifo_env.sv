`ifndef FIFO_ENV_SV
`define FIFO_ENV_SV

class fifo_env extends uvm_env;

    `uvm_component_utils(fifo_env)

    fifo_agent             agent;
    fifo_scoreboard        sb;
    fifo_coverage          cov;
    fifo_virtual_sequencer vseqr;

    function new(string name = "fifo_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = fifo_agent::type_id::create("agent", this);
        sb    = fifo_scoreboard::type_id::create("sb", this);
        cov   = fifo_coverage::type_id::create("cov", this);
        vseqr = fifo_virtual_sequencer::type_id::create("vseqr", this);

        `uvm_info("ENV", "All components created in build_phase", UVM_LOW)
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agent.wr_ap.connect(sb.wr_imp);
        agent.rd_ap.connect(sb.rd_imp);

        agent.wr_ap.connect(cov.wr_imp);
        agent.rd_ap.connect(cov.rd_imp);

        vseqr.fifo_seqr = agent.sequencer;

        `uvm_info("ENV", "All TLM connections made in connect_phase", UVM_LOW)
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        `uvm_info("ENV", "UVM Topology:", UVM_MEDIUM)
        uvm_top.print_topology();
    endfunction

endclass : fifo_env

`endif