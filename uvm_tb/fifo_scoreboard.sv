`ifndef FIFO_SCOREBOARD_SV
`define FIFO_SCOREBOARD_SV

`uvm_analysis_imp_decl(_wr)
`uvm_analysis_imp_decl(_rd)

class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp_wr #(fifo_wr_obs, fifo_scoreboard) wr_imp;
    uvm_analysis_imp_rd #(fifo_rd_obs, fifo_scoreboard) rd_imp;

    bit [7:0] ref_q[$];

    int unsigned wr_accepted;
    int unsigned wr_rejected;
    int unsigned rd_accepted;
    int unsigned rd_rejected;
    int unsigned match_count;
    int unsigned mismatch_count;
    int unsigned max_occupancy;

    function new(string name = "fifo_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_imp = new("wr_imp", this);
        rd_imp = new("rd_imp", this);
    endfunction

    function void write_wr(fifo_wr_obs obs);

        if (!obs.wr_rst_n) begin
            if (ref_q.size() > 0)
                `uvm_info("SB",
                    $sformatf("RESET detected on wr domain — clearing %0d items from ref_q",
                    ref_q.size()), UVM_LOW)
            ref_q.delete();
            return;
        end

        if (obs.wr_en && !obs.wr_full) begin
            ref_q.push_back(obs.wr_data);
            wr_accepted++;

            if (ref_q.size() > max_occupancy)
                max_occupancy = ref_q.size();

            `uvm_info("SB",
                $sformatf("WR ACCEPTED: data=0x%02h | ref_q depth=%0d",
                obs.wr_data, ref_q.size()), UVM_HIGH)
        end
        else if (obs.wr_en && obs.wr_full) begin
            wr_rejected++;
            `uvm_info("SB",
                "WR REJECTED: wr_full asserted — DUT correctly blocked write",
                UVM_HIGH)
        end

    endfunction : write_wr

    function void write_rd(fifo_rd_obs obs);

        if (!obs.rd_rst_n) begin
            `uvm_info("SB", "RESET detected on rd domain", UVM_LOW)
            return;
        end

        if (obs.rd_en && !obs.rd_empty) begin
            rd_accepted++;

            if (ref_q.size() == 0) begin
                `uvm_error("SB",
                    $sformatf(
                    "DUT delivered read data (rd_en=1, rd_empty=0) but \
reference queue is EMPTY at t=%0t. \
DUT empty flag or pointer logic is broken.",
                    obs.timestamp))
                mismatch_count++;
                return;
            end

            begin
                bit [7:0] expected_data;
                expected_data = ref_q.pop_front();

                if (obs.rd_data !== expected_data) begin
                    `uvm_error("SB",
                        $sformatf(
                        "DATA MISMATCH at t=%0t | expected=0x%02h actual=0x%02h | \
ref_q remaining=%0d",
                        obs.timestamp,
                        expected_data,
                        obs.rd_data,
                        ref_q.size()))
                    mismatch_count++;
                end
                else begin
                    match_count++;
                    `uvm_info("SB",
                        $sformatf(
                        "DATA MATCH: 0x%02h | ref_q remaining=%0d",
                        obs.rd_data,
                        ref_q.size()),
                        UVM_HIGH)
                end
            end
        end
        else if (obs.rd_en && obs.rd_empty) begin
            rd_rejected++;
            `uvm_info("SB",
                "RD REJECTED: rd_empty asserted — DUT correctly blocked read",
                UVM_HIGH)
        end

    endfunction : write_rd

    function void report_phase(uvm_phase phase);

        `uvm_info("SB", "==========================================", UVM_NONE)
        `uvm_info("SB", "         SCOREBOARD FINAL REPORT          ", UVM_NONE)
        `uvm_info("SB", "==========================================", UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Writes accepted    : %0d", wr_accepted),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Writes rejected    : %0d (full flag)",
            wr_rejected),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Reads  accepted    : %0d", rd_accepted),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Reads  rejected    : %0d (empty flag)",
            rd_rejected),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Data matches       : %0d",
            match_count),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Data mismatches    : %0d",
            mismatch_count),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Max occupancy seen : %0d",
            max_occupancy),
            UVM_NONE)

        `uvm_info("SB",
            $sformatf("  Ref queue residue  : %0d",
            ref_q.size()),
            UVM_NONE)

        if (ref_q.size() > 0)
            `uvm_warning("SB",
                $sformatf(
                "%0d items remain in ref_q — test did not fully drain FIFO",
                ref_q.size()))

        if (mismatch_count == 0) begin
            `uvm_info("SB", "==========================================", UVM_NONE)
            `uvm_info("SB", "        SCOREBOARD RESULT: PASS           ", UVM_NONE)
            `uvm_info("SB", "==========================================", UVM_NONE)
        end
        else begin
            `uvm_error("SB","==========================================")
            `uvm_error("SB","        SCOREBOARD RESULT: FAIL           ")
            `uvm_error("SB","==========================================")
        end

    endfunction : report_phase

endclass : fifo_scoreboard

`endif