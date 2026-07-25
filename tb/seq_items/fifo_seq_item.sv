
`ifndef FIFO_SEQ_ITEM_SV
`define FIFO_SEQ_ITEM_SV

class fifo_seq_item extends uvm_sequence_item;

    rand logic                  wr_en;
    rand logic [DATA_WIDTH-1:0] wr_data;
    rand logic                  rd_en;

    rand int unsigned wr_idle_cycles;
    rand int unsigned rd_idle_cycles;

    constraint c_wr_idle { wr_idle_cycles inside {[0:4]}; }
    constraint c_rd_idle { rd_idle_cycles inside {[0:4]}; }
    constraint c_data    { soft wr_data != '0; }

    `uvm_object_utils_begin(fifo_seq_item)
        `uvm_field_int(wr_en,          UVM_ALL_ON)
        `uvm_field_int(wr_data,        UVM_ALL_ON)
        `uvm_field_int(rd_en,          UVM_ALL_ON)
        `uvm_field_int(wr_idle_cycles, UVM_ALL_ON)
        `uvm_field_int(rd_idle_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "[TXN] wr_en=%0b wr_data=0x%02h rd_en=%0b | wr_idle=%0d rd_idle=%0d",
            wr_en, wr_data, rd_en,
            wr_idle_cycles, rd_idle_cycles);
    endfunction

endclass : fifo_seq_item

`endif

