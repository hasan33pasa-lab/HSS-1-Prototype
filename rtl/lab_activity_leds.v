// Tang Nano 20K LEDs are active low.
// LED0 records that Main has retired at least one instruction; LED1 does the
// same for Guard. A supervisor trip lights all six LEDs as a visible fault.
module lab_activity_leds (
    input  wire        reset_n,
    input  wire [15:0] main_retired_count,
    input  wire [15:0] guard_retired_count,
    input  wire        supervisor_trip,
    output wire [5:0]  led_n
);
    wire main_started = (main_retired_count != 16'd0);
    wire guard_started = (guard_retired_count != 16'd0);

    assign led_n = !reset_n       ? 6'b111111 :
                   supervisor_trip ? 6'b000000 :
                   {4'b1111, ~guard_started, ~main_started};
endmodule
