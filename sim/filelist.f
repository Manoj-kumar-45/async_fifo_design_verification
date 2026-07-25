##############################################################
## File : sim/filelist.f
## All source files in compile dependency order 
##############################################################

## ---- RTL files ----
../rtl/sync_2ff.sv
../rtl/fifo_mem.sv
../rtl/wr_ptr_ctrl.sv
../rtl/rd_ptr_ctrl.sv
../rtl/async_fifo_top.sv

## ---- Interface (must be before package) ----
../tb/interfaces/fifo_if.sv

## ---- TB Package (contains all UVM classes) ----
../tb/fifo_tb_pkg.sv

## ---- Assertions bind module (after DUT) ----
../tb/assertions/fifo_assertions.sv

## ---- TB Top ----
../tb/top/fifo_tb_top.sv

## ---- Include directories for `include resolution ----
+incdir+../tb/seq_items
+incdir+../tb/agents
+incdir+../tb/env
+incdir+../tb/sequences
+incdir+../tb/tests
+incdir+../tb