module tangnano20k_wide16_lab_top #(
    parameter integer STEP_DIVISOR = 13500000,
    parameter integer KEY_FILTER_CYCLES = 270000
) (
    input  wire       clk_27mhz,
    input  wire       key1_reset,
    input  wire       key2_stall_test,
    output wire [5:0] led_n
);
    reg [23:0] step_divider = 24'd0;
    wire step_enable = (step_divider == STEP_DIVISOR - 1);
    reg [3:0] reset_pipeline = 4'b0000;
    wire key1_pressed;
    wire key2_pressed;
    wire reset_n = reset_pipeline[3] && !key1_pressed;
    reg key2_was_pressed = 1'b0;
    reg main_stall_test_latched = 1'b0;

    wire [15:0] main_result;
    wire [15:0] guard_result;
    wire [15:0] guard_probe;
    wire [15:0] main_retired_count;
    wire [15:0] guard_retired_count;
    wire main_done;
    wire guard_done;
    wire result_disagreement;
    wire supervisor_trip;

    button_filter #(.STABLE_CYCLES(KEY_FILTER_CYCLES)) key1_filter (
        .clk(clk_27mhz), .button_in(key1_reset), .button_pressed(key1_pressed)
    );
    button_filter #(.STABLE_CYCLES(KEY_FILTER_CYCLES)) key2_filter (
        .clk(clk_27mhz), .button_in(key2_stall_test), .button_pressed(key2_pressed)
    );

    always @(posedge clk_27mhz)
        reset_pipeline <= {reset_pipeline[2:0], 1'b1};

    always @(posedge clk_27mhz) begin
        if (!reset_n)
            step_divider <= 24'd0;
        else if (step_enable)
            step_divider <= 24'd0;
        else
            step_divider <= step_divider + 1'b1;
    end

    always @(posedge clk_27mhz) begin
        if (!reset_n) begin
            key2_was_pressed <= 1'b0;
            main_stall_test_latched <= 1'b0;
        end else begin
            key2_was_pressed <= key2_pressed;
            if (key2_pressed && !key2_was_pressed)
                main_stall_test_latched <= 1'b1;
        end
    end

    dual_core_wide16_lab_top wide16_demo (
        .clk(clk_27mhz),
        .reset_n(reset_n),
        .step_enable(step_enable),
        .main_stall_test(main_stall_test_latched),
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

    lab_activity_leds activity_display (
        .reset_n(reset_n),
        .main_retired_count(main_retired_count),
        .guard_retired_count(guard_retired_count),
        .supervisor_trip(supervisor_trip),
        .led_n(led_n)
    );
endmodule
