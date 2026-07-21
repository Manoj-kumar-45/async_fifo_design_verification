`ifndef FIFO_TB_PKG_SV
`define FIFO_TB_PKG_SV

package fifo_tb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "fifo_seq_item.sv"
    `include "fifo_sequencer.sv"
    `include "fifo_sequences.sv"
    `include "fifo_driver.sv"
    `include "fifo_monitor.sv"
    `include "fifo_agent.sv"
    `include "fifo_scoreboard.sv"
    `include "fifo_coverage.sv"
    `include "fifo_virtual_sequencer.sv"
    `include "fifo_env.sv"
    `include "fifo_virtual_sequences.sv"
    `include "fifo_base_test.sv"
    `include "fifo_directed_tests.sv"
    `include "fifo_random_tests.sv"

endpackage : fifo_tb_pkg

`endif