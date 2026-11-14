// Bench-only stop supervisor. It detects a core whose retired-instruction
// counter stops changing while the core is still active, then latches a hold.
// This detects a stall only; it does not verify instruction correctness.
module progress_watchdog #(
    parameter integer WATCHDOG_LIMIT = 4
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        sample_enable,
    input  wire        active,
    input  wire [15:0] progress_count,
    output reg         trip
);
    // The idle counter only needs to represent 0..WATCHDOG_LIMIT-1.
    // Preserve one bit for the limit=1 case, where clog2(1) is zero.
    localparam integer IDLE_COUNTER_WIDTH = (WATCHDOG_LIMIT <= 2) ? 1 : $clog2(WATCHDOG_LIMIT);
    reg [15:0] previous_count;
    reg [IDLE_COUNTER_WIDTH-1:0] idle_cycles;

    always @(posedge clk) begin
        if (!reset_n) begin
            previous_count <= 16'd0;
            idle_cycles <= {IDLE_COUNTER_WIDTH{1'b0}};
            trip <= 1'b0;
        end else if (trip) begin
            trip <= 1'b1;
        end else if (sample_enable) begin
            if (!active) begin
                previous_count <= progress_count;
                idle_cycles <= {IDLE_COUNTER_WIDTH{1'b0}};
            end else if (progress_count != previous_count) begin
                previous_count <= progress_count;
                idle_cycles <= {IDLE_COUNTER_WIDTH{1'b0}};
            end else if (idle_cycles >= WATCHDOG_LIMIT - 1) begin
                trip <= 1'b1;
            end else begin
                idle_cycles <= idle_cycles + 1'b1;
            end
        end
    end
endmodule
