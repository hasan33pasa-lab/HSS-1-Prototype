module tb_wide_tiny_core;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg main_run_enable = 1'b1;
    wire [7:0] main_pc;
    wire [7:0] guard_pc;
    wire [15:0] main_instruction;
    wire [15:0] guard_instruction;
    wire [5:0] main_check;
    wire [5:0] guard_check;
    wire [15:0] main_r2;
    wire [15:0] guard_r2;
    wire [15:0] main_result;
    wire [15:0] guard_result;
    wire [15:0] main_retired;
    wire [15:0] guard_retired;
    wire main_halted;
    wire guard_halted;

    always #5 clk = ~clk;

    wide16_main_program_rom main_rom (
        .address(main_pc), .instruction(main_instruction), .instruction_check(main_check)
    );
    wide16_guard_program_rom guard_rom (
        .address(guard_pc), .instruction(guard_instruction), .instruction_check(guard_check)
    );

    wide_tiny_core main_core (
        .clk(clk), .reset_n(reset_n), .run_enable(main_run_enable),
        .instruction(main_instruction), .pc(main_pc), .debug_r2(main_r2),
        .result(main_result), .retired_count(main_retired), .halted(main_halted)
    );
    wide_tiny_core guard_core (
        .clk(clk), .reset_n(reset_n), .run_enable(1'b1),
        .instruction(guard_instruction), .pc(guard_pc), .debug_r2(guard_r2),
        .result(guard_result), .retired_count(guard_retired), .halted(guard_halted)
    );

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        main_run_enable = 1'b0;
        #1;
        if (main_pc !== 8'd3 || main_retired !== 16'd3 || main_core.registers[0] !== 16'h1234)
            $fatal(1, "wide Main state did not reach or preserve its first 16-bit constant");
        repeat (3) @(posedge clk);
        #1;
        if (main_pc !== 8'd3 || main_retired !== 16'd3 || main_core.registers[0] !== 16'h1234)
            $fatal(1, "run_enable failed to hold all wide-core architectural state");
        @(negedge clk);
        main_run_enable = 1'b1;
        wait (main_halted && guard_halted);
        #1;
        if (main_result !== 16'h00C0 || guard_result !== 16'h00C0 ||
            main_retired !== 16'd10 || guard_retired !== 16'd7)
            $fatal(1, "wide cores returned an incorrect synthetic 16-bit delta");
        if (main_core.data_memory[0] !== 16'h00C0 || guard_core.data_memory[0] !== 16'd0)
            $fatal(1, "wide private RAM store/load or isolation failed");
        if (main_core.registers[1] !== 16'h00C0 || guard_core.registers[0] !== 16'h00C0)
            $fatal(1, "LDIH or 16-bit subtraction produced the wrong register value");

        @(negedge clk);
        reset_n = 1'b0;
        @(posedge clk);
        #1;
        if (main_pc !== 8'd0 || guard_pc !== 8'd0 || main_retired !== 16'd0 ||
            guard_retired !== 16'd0 || main_result !== 16'd0 || guard_result !== 16'd0 ||
            main_halted || guard_halted)
            $fatal(1, "wide-core reset did not clear state");

        $display("PASS: wide 16-bit constants, ALU, private RAM, run-enable hold, and reset");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "wide-core testbench timeout");
    end
endmodule
