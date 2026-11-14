// Separate two-core 16-bit profile. It is not the default Tang Nano board top.
module dual_core_wide16_lab_top (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        step_enable,
    input  wire        main_stall_test,
    output wire [15:0] main_result,
    output wire [15:0] guard_result,
    output wire [15:0] guard_probe,
    output wire [15:0] main_retired_count,
    output wire [15:0] guard_retired_count,
    output wire        main_done,
    output wire        guard_done,
    output wire        result_disagreement,
    output wire        supervisor_trip
);
    wire [7:0] main_pc;
    wire [7:0] guard_pc;
    wire [15:0] main_r2;
    wire [15:0] guard_r2;
    wire [15:0] main_instruction;
    wire [15:0] guard_instruction;
    wire [5:0] main_instruction_check;
    wire [5:0] guard_instruction_check;
    wire main_watchdog_trip;
    wire guard_watchdog_trip;
    wire main_instruction_check_fault;
    wire guard_instruction_check_fault;
    wire instruction_check_fault;
    wire instruction_integrity_fault;
    wire main_run_enable;
    wire guard_run_enable;
    reg instruction_integrity_fault_latched;
    reg result_disagreement_latched;

    function [5:0] encode_instruction_check;
        input [15:0] instruction_word;
        reg [4:0] hamming_bits;
        integer position;
        integer data_index;
        begin
            hamming_bits = 5'b0;
            data_index = 0;
            for (position = 1; position <= 21; position = position + 1) begin
                if ((position != 1) && (position != 2) && (position != 4) &&
                    (position != 8) && (position != 16)) begin
                    if ((position & 1) != 0)
                        hamming_bits[0] = hamming_bits[0] ^ instruction_word[data_index];
                    if ((position & 2) != 0)
                        hamming_bits[1] = hamming_bits[1] ^ instruction_word[data_index];
                    if ((position & 4) != 0)
                        hamming_bits[2] = hamming_bits[2] ^ instruction_word[data_index];
                    if ((position & 8) != 0)
                        hamming_bits[3] = hamming_bits[3] ^ instruction_word[data_index];
                    if ((position & 16) != 0)
                        hamming_bits[4] = hamming_bits[4] ^ instruction_word[data_index];
                    data_index = data_index + 1;
                end
            end
            encode_instruction_check[4:0] = hamming_bits;
            encode_instruction_check[5] = ^{instruction_word, hamming_bits};
        end
    endfunction

    assign main_instruction_check_fault =
        main_instruction_check != encode_instruction_check(main_instruction);
    assign guard_instruction_check_fault =
        guard_instruction_check != encode_instruction_check(guard_instruction);
    assign instruction_check_fault = main_instruction_check_fault | guard_instruction_check_fault;
    assign instruction_integrity_fault = instruction_check_fault | instruction_integrity_fault_latched;
    assign result_disagreement = result_disagreement_latched;
    assign supervisor_trip = main_watchdog_trip | guard_watchdog_trip |
                             instruction_integrity_fault | result_disagreement_latched;

    assign main_run_enable = !supervisor_trip && step_enable && !main_stall_test;
    // Preserve the original lab behavior: a Main stall leaves Guard able to
    // finish its independent calculation; a Guard stall or integrity fault holds both.
    assign guard_run_enable = !(guard_watchdog_trip | instruction_integrity_fault |
                                result_disagreement_latched) && step_enable;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            instruction_integrity_fault_latched <= 1'b0;
            result_disagreement_latched <= 1'b0;
        end else begin
            if (instruction_check_fault)
                instruction_integrity_fault_latched <= 1'b1;
            if (main_done && guard_done && (main_result != guard_result))
                result_disagreement_latched <= 1'b1;
        end
    end

    progress_watchdog main_progress_watchdog (
        .clk(clk),
        .reset_n(reset_n),
        .active(!main_done && !guard_watchdog_trip && !instruction_integrity_fault &&
                !result_disagreement_latched),
        .sample_enable(step_enable),
        .progress_count(main_retired_count),
        .trip(main_watchdog_trip)
    );

    progress_watchdog guard_progress_watchdog (
        .clk(clk),
        .reset_n(reset_n),
        .active(!guard_done && !instruction_integrity_fault && !result_disagreement_latched),
        .sample_enable(step_enable),
        .progress_count(guard_retired_count),
        .trip(guard_watchdog_trip)
    );

    wide16_main_program_rom main_program (
        .address(main_pc),
        .instruction(main_instruction),
        .instruction_check(main_instruction_check)
    );
    wide16_guard_program_rom guard_program (
        .address(guard_pc),
        .instruction(guard_instruction),
        .instruction_check(guard_instruction_check)
    );

    wide_tiny_core main_core (
        .clk(clk),
        .reset_n(reset_n),
        .run_enable(main_run_enable),
        .instruction(main_instruction),
        .pc(main_pc),
        .debug_r2(main_r2),
        .result(main_result),
        .retired_count(main_retired_count),
        .halted(main_done)
    );

    wide_tiny_core guard_core (
        .clk(clk),
        .reset_n(reset_n),
        .run_enable(guard_run_enable),
        .instruction(guard_instruction),
        .pc(guard_pc),
        .debug_r2(guard_r2),
        .result(guard_result),
        .retired_count(guard_retired_count),
        .halted(guard_done)
    );

    assign guard_probe = guard_r2;
endmodule
