`ifndef FIFO_COVERAGE_SV
`define FIFO_COVERAGE_SV

`uvm_analysis_imp_decl(_wrcov)
`uvm_analysis_imp_decl(_rdcov)

class fifo_coverage extends uvm_component;
    `uvm_component_utils(fifo_coverage)

    uvm_analysis_imp_wrcov #(fifo_wr_obs, fifo_coverage) wr_imp;
    uvm_analysis_imp_rdcov #(fifo_rd_obs, fifo_coverage) rd_imp;

    int unsigned fifo_depth = 16;

    int unsigned shadow_occupancy;
    int unsigned wrap_count;

    bit wr_full_latched;
    bit rd_empty_latched;
    bit wr_rst_n_latched = 1'b1;
    bit rd_rst_n_latched = 1'b1;

    bit last_wr_accepted;
    bit last_rd_accepted;

    covergroup cg_occupancy;
        option.per_instance = 1;
        option.name = "cg_occupancy";

        cp_occ: coverpoint shadow_occupancy {
            bins empty = {0};
            bins low   = {[1 : fifo_depth/4]};
            bins mid   = {[(fifo_depth/4)+1 : (3*fifo_depth/4)-1]};
            bins high  = {[(3*fifo_depth/4) : fifo_depth-1]};
            bins full  = {fifo_depth};
        }
    endgroup

    covergroup cg_flags;
        option.per_instance = 1;
        option.name = "cg_flags";

        cp_full: coverpoint wr_full_latched {
            bins asserted   = {1};
            bins deasserted = {0};
        }

        cp_empty: coverpoint rd_empty_latched {
            bins asserted   = {1};
            bins deasserted = {0};
        }

        cx_full_empty: cross cp_full, cp_empty {
            illegal_bins both_asserted =
                binsof(cp_full.asserted) && binsof(cp_empty.asserted);
        }
    endgroup

    covergroup cg_simultaneous;
        option.per_instance = 1;
        option.name = "cg_simultaneous";

        cp_simul: coverpoint (last_wr_accepted && last_rd_accepted) {
            bins both_active = {1};
            bins not_both    = {0};
        }
    endgroup

    covergroup cg_wraparound;
        option.per_instance = 1;
        option.name = "cg_wraparound";

        cp_wraps: coverpoint wrap_count {
            bins no_wrap    = {0};
            bins one_wrap   = {1};
            bins few_wraps  = {[2:3]};
            bins many_wraps = {[4:$]};
        }
    endgroup

    covergroup cg_reset;
        option.per_instance = 1;
        option.name = "cg_reset";

        cp_wr_rst: coverpoint wr_rst_n_latched {
            bins asserted   = {0};
            bins deasserted = {1};
        }

        cp_rd_rst: coverpoint rd_rst_n_latched {
            bins asserted   = {0};
            bins deasserted = {1};
        }

        cp_occ_at_reset: coverpoint shadow_occupancy {
            bins reset_while_empty = {0};
            bins reset_while_mid   = {[1 : fifo_depth-1]};
            bins reset_while_full  = {fifo_depth};
        }

        cx_reset_occupancy: cross cp_wr_rst, cp_occ_at_reset;
    endgroup

    function new(string name = "fifo_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_occupancy    = new();
        cg_flags        = new();
        cg_simultaneous = new();
        cg_wraparound   = new();
        cg_reset        = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_imp = new("wr_imp", this);
        rd_imp = new("rd_imp", this);

        void'(uvm_config_db #(int unsigned)::get(
            this, "", "fifo_depth", fifo_depth));
    endfunction

    function void write_wrcov(fifo_wr_obs obs);

        wr_rst_n_latched = obs.wr_rst_n;

        if (!obs.wr_rst_n) begin
            shadow_occupancy = 0;
            last_wr_accepted = 0;
            cg_reset.sample();
            return;
        end

        wr_full_latched = obs.wr_full;

        if (obs.wr_en && !obs.wr_full) begin
            shadow_occupancy++;
            last_wr_accepted = 1;

            if (shadow_occupancy == fifo_depth) begin
                wrap_count++;
                cg_wraparound.sample();
            end
        end
        else begin
            last_wr_accepted = 0;
        end

        cg_occupancy.sample();
        cg_flags.sample();
        cg_simultaneous.sample();

    endfunction : write_wrcov

    function void write_rdcov(fifo_rd_obs obs);

        rd_rst_n_latched = obs.rd_rst_n;

        if (!obs.rd_rst_n) begin
            shadow_occupancy = 0;
            last_rd_accepted = 0;
            cg_reset.sample();
            return;
        end

        rd_empty_latched = obs.rd_empty;

        if (obs.rd_en && !obs.rd_empty) begin
            if (shadow_occupancy > 0)
                shadow_occupancy--;

            last_rd_accepted = 1;
        end
        else begin
            last_rd_accepted = 0;
        end

        cg_occupancy.sample();
        cg_flags.sample();
        cg_simultaneous.sample();

    endfunction : write_rdcov

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", "==========================================", UVM_NONE)
        `uvm_info("COV", "         FUNCTIONAL COVERAGE REPORT       ", UVM_NONE)
        `uvm_info("COV", "==========================================", UVM_NONE)
        `uvm_info("COV", $sformatf("  Occupancy          : %0.1f%%", cg_occupancy.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("  Full/Empty flags   : %0.1f%%", cg_flags.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("  Simultaneous Wr+Rd : %0.1f%%", cg_simultaneous.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("  Pointer Wraparound : %0.1f%%", cg_wraparound.get_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("  Reset Scenarios    : %0.1f%%", cg_reset.get_coverage()), UVM_NONE)
        `uvm_info("COV", "==========================================", UVM_NONE)
    endfunction : report_phase

endclass : fifo_coverage

`endif