`ifndef FIFO_VIRTUAL_SEQUENCER_SV
`define FIFO_VIRTUAL_SEQUENCER_SV

class fifo_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(fifo_virtual_sequencer)

    fifo_sequencer fifo_seqr;

    function new(string name = "fifo_virtual_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : fifo_virtual_sequencer

`endif