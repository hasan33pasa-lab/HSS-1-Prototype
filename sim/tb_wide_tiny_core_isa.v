module tb_wide_tiny_core_isa;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg run_enable = 1'b0;
    reg [15:0] instruction = 16'h0000;
    wire [7:0] pc;
    wire [15:0] debug_r2;
    wire [15:0] result;
    wire [15:0] retired_count;
    wire halted;

    always #5 clk = ~clk;

    wide_tiny_core dut (
        .clk(clk), .reset_n(reset_n), .run_enable(run_enable),
        .instruction(instruction), .pc(pc), .debug_r2(debug_r2),
        .result(result), .retired_count(retired_count), .halted(halted)
    );

    task apply_instruction;
        input [15:0] word;
        input [7:0] expected_pc;
        input [15:0] expected_retired;
        begin
            @(negedge clk);
            instruction = word;
            run_enable = 1'b1;
            @(posedge clk);
            #1;
            if (pc !== expected_pc || retired_count !== expected_retired)
                $fatal(1, "instruction %04h produced PC=%02h retired=%04h", word, pc, retired_count);
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1;
        if (pc !== 8'd0 || retired_count !== 16'd0 || halted)
            $fatal(1, "wide core reset did not initialize architectural state");
        @(negedge clk);
        reset_n = 1'b1;

        apply_instruction(16'h0000, 8'h01, 16'd1); // NOP
        apply_instruction(16'h10FE, 8'h02, 16'd2); // LDI R0, FE
        if (dut.registers[0] !== 16'h00FE) $fatal(1, "LDI failed");
        apply_instruction(16'hF112, 8'h03, 16'd3); // LDIH R0, 12
        if (dut.registers[0] !== 16'h12FE) $fatal(1, "LDIH did not preserve the low byte");
        apply_instruction(16'h20FF, 8'h04, 16'd4); // ADDI R0, FF
        if (dut.registers[0] !== 16'h13FD) $fatal(1, "ADDI failed");
        apply_instruction(16'h30AA, 8'h05, 16'd5); // XORI R0, AA
        if (dut.registers[0] !== 16'h1357) $fatal(1, "XORI failed");
        apply_instruction(16'h1403, 8'h06, 16'd6); // LDI R1, 03
        apply_instruction(16'h9100, 8'h07, 16'd7); // ADD R0, R1
        if (dut.registers[0] !== 16'h135A) $fatal(1, "ADD failed");
        apply_instruction(16'hA100, 8'h08, 16'd8); // SUB R0, R1
        if (dut.registers[0] !== 16'h1357) $fatal(1, "SUB failed");
        apply_instruction(16'hB100, 8'h09, 16'd9); // AND R0, R1
        if (dut.registers[0] !== 16'h0003) $fatal(1, "AND failed");
        apply_instruction(16'h1057, 8'h0A, 16'd10); // Reload lower byte
        apply_instruction(16'hF113, 8'h0B, 16'd11); // Reload upper byte
        apply_instruction(16'hC100, 8'h0C, 16'd12); // OR R0, R1
        if (dut.registers[0] !== 16'h1357) $fatal(1, "OR failed");
        apply_instruction(16'hD100, 8'h0D, 16'd13); // XOR R0, R1
        if (dut.registers[0] !== 16'h1354) $fatal(1, "XOR failed");
        apply_instruction(16'hE800, 8'h0E, 16'd14); // MOV R2, R0
        if (dut.registers[2] !== 16'h1354) $fatal(1, "MOV failed");
        apply_instruction(16'h4800, 8'h0F, 16'd15); // OUT R2
        if (result !== 16'h1354) $fatal(1, "OUT failed");
        apply_instruction(16'h8A0F, 8'h10, 16'd16); // STORE R2, 15
        apply_instruction(16'h7C0F, 8'h11, 16'd17); // LOAD R3, 15
        if (dut.registers[3] !== 16'h1354 || dut.data_memory[15] !== 16'h1354)
            $fatal(1, "private RAM LOAD/STORE failed");
        apply_instruction(16'h6C3F, 8'h12, 16'd18); // JZ R3, 3F; not taken
        apply_instruction(16'h1C00, 8'h13, 16'd19); // LDI R3, 0
        apply_instruction(16'hFD01, 8'h14, 16'd20); // LDIH R3, 01
        apply_instruction(16'h6C40, 8'h15, 16'd21); // JZ sees high byte; not taken
        apply_instruction(16'h5030, 8'h30, 16'd22); // JMP 30

        apply_instruction(16'h10FF, 8'h31, 16'd23); // LDI R0, FF
        apply_instruction(16'hF1FF, 8'h32, 16'd24); // LDIH R0, FF -> FFFF
        apply_instruction(16'h2001, 8'h33, 16'd25); // ADDI wraps to 0000
        if (dut.registers[0] !== 16'h0000) $fatal(1, "16-bit arithmetic did not wrap");
        apply_instruction(16'h6022, 8'h22, 16'd26); // JZ R0, 22; taken
        apply_instruction(16'hF000, 8'h22, 16'd27); // HALT holds PC
        if (!halted) $fatal(1, "HALT failed");

        @(negedge clk);
        reset_n = 1'b0;
        @(posedge clk);
        #1;
        if (pc !== 8'd0 || retired_count !== 16'd0 || halted || result !== 16'd0 ||
            dut.registers[0] !== 16'd0 || dut.registers[3] !== 16'd0 || dut.data_memory[15] !== 16'd0)
            $fatal(1, "reset did not clear registers, private RAM, and output");

        @(negedge clk);
        reset_n = 1'b1;
        apply_instruction(16'hF200, 8'h00, 16'd1); // Reserved F-group word stops safely
        if (!halted) $fatal(1, "reserved F-group encoding did not stop the core");

        $display("PASS: wide 16-bit ISA opcodes, branches, wraparound, private RAM, halt, and reset");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "wide 16-bit ISA testbench timeout");
    end
endmodule
