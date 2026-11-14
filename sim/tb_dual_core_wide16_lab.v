module tb_dual_core_wide16_lab;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg step_enable = 1'b1;
    reg main_stall_test = 1'b0;
    wire [15:0] main_result;
    wire [15:0] guard_result;
    wire [15:0] guard_probe;
    wire [15:0] main_retired_count;
    wire [15:0] guard_retired_count;
    wire main_done;
    wire guard_done;
    wire result_disagreement;
    wire supervisor_trip;

    always #5 clk = ~clk;

    dual_core_wide16_lab_top dut (
        .clk(clk),
        .reset_n(reset_n),
        .step_enable(step_enable),
        .main_stall_test(main_stall_test),
        .main_result(main_result),
        .guard_result(guard_result),
        .guard_probe(guard_probe),
        .main_retired_count(main_retired_count),
        .guard_retired_count(guard_retired_count),
        .main_done(main_done),
        .guard_done(guard_done),
        .result_disagreement(result_disagreement),
        .supervisor_trip(supervisor_trip)
    );

    task apply_reset;
        begin
            @(negedge clk);
            reset_n = 1'b0;
            main_stall_test = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (main_retired_count !== 16'd0 || guard_retired_count !== 16'd0 ||
                main_result !== 16'd0 || guard_result !== 16'd0 ||
                main_done || guard_done || supervisor_trip || result_disagreement)
                $fatal(1, "wide dual-core reset failed to clear the architecture and supervisor");
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1'b1;
        wait (main_done && guard_done);
        #1;
        if (main_result !== 16'h00C0 || guard_result !== 16'h00C0 ||
            main_retired_count !== 16'd10 || guard_retired_count !== 16'd7 ||
            guard_probe !== 16'd0 || supervisor_trip || result_disagreement)
            $fatal(1, "independent 16-bit coordinate-delta programs failed");
        if (dut.main_core.data_memory[0] !== 16'h00C0 || dut.guard_core.data_memory[0] !== 16'd0)
            $fatal(1, "wide cores shared private data RAM");

        force dut.guard_result = 16'h00C1;
        @(posedge clk);
        #1;
        if (!result_disagreement || !supervisor_trip)
            $fatal(1, "completed-result disagreement was not latched as a supervisor trip");
        release dut.guard_result;
        apply_reset();

        main_stall_test = 1'b1;
        @(negedge clk);
        reset_n = 1'b1;
        wait (supervisor_trip);
        #1;
        if (main_retired_count !== 16'd0 || !dut.main_watchdog_trip)
            $fatal(1, "Main progress watchdog did not detect the injected stall");
        apply_reset();

        @(negedge clk);
        reset_n = 1'b1;
        force dut.main_instruction = 16'h1035; // Flip one bit in Main's stored 16'h1034 LDI.
        #1;
        if (!supervisor_trip || main_retired_count !== 16'd0 || guard_retired_count !== 16'd0)
            $fatal(1, "wide ROM SECDED did not block retirement on a corrupted instruction");
        @(posedge clk);
        #1;
        if (!dut.instruction_integrity_fault_latched || main_retired_count !== 16'd0 ||
            guard_retired_count !== 16'd0)
            $fatal(1, "wide ROM integrity fault was not latched before retirement");
        release dut.main_instruction;
        apply_reset();

        $display("PASS: two independent 16-bit cores, result agreement, private RAM, watchdog, and ROM SECDED");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "wide dual-core testbench timeout");
    end
endmodule
