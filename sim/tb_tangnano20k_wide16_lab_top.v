module tb_tangnano20k_wide16_lab_top;
    reg clk_27mhz = 1'b0;
    reg key1_reset = 1'b0;
    reg key2_stall_test = 1'b0;
    wire [5:0] led_n;

    always #5 clk_27mhz = ~clk_27mhz;

    tangnano20k_wide16_lab_top #(
        .STEP_DIVISOR(4),
        .KEY_FILTER_CYCLES(2)
    ) dut (
        .clk_27mhz(clk_27mhz),
        .key1_reset(key1_reset),
        .key2_stall_test(key2_stall_test),
        .led_n(led_n)
    );

    initial begin
        #1;
        if (led_n !== 6'b111111)
            $fatal(1, "wide16 board LEDs should be off during reset");
        wait (dut.main_retired_count != 16'd0 && dut.guard_retired_count != 16'd0);
        #1;
        if (led_n !== 6'b111100)
            $fatal(1, "wide16 board should show both core activity LEDs");
        wait (dut.main_done && dut.guard_done);
        #1;
        if (dut.main_result !== 16'h00C0 || dut.guard_result !== 16'h00C0 ||
            dut.result_disagreement || led_n !== 6'b111100)
            $fatal(1, "wide16 board demo should finish with matching synthetic deltas");

        @(negedge clk_27mhz);
        key1_reset = 1'b1;
        wait (dut.reset_n === 1'b0);
        #1;
        if (led_n !== 6'b111111)
            $fatal(1, "S1 reset should clear wide16 LED activity");
        @(negedge clk_27mhz);
        key1_reset = 1'b0;
        wait (dut.reset_n === 1'b1);
        @(negedge clk_27mhz);
        key2_stall_test = 1'b1;
        repeat (5) @(posedge clk_27mhz);
        @(negedge clk_27mhz);
        key2_stall_test = 1'b0;
        wait (dut.supervisor_trip);
        #1;
        if (!dut.wide16_demo.main_watchdog_trip || led_n !== 6'b000000)
            $fatal(1, "S2 should cause a Main watchdog trip and light all six LEDs");

        $display("PASS: wide16 board activity, S1 reset, and S2 watchdog fault display");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "wide16 board-wrapper testbench timeout");
    end
endmodule
