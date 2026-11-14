// Two-flop synchronizer and stable-level filter for a mechanical board key.
// The Tang Nano 20K keys are pulled low when idle and drive high when pressed.
module button_filter #(
    parameter integer STABLE_CYCLES = 270000
) (
    input  wire clk,
    input  wire button_in,
    output reg  button_pressed = 1'b0
);
    localparam integer COUNT_WIDTH = (STABLE_CYCLES <= 2) ? 1 : $clog2(STABLE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg [1:0] button_sync = 2'b00;
    reg [COUNT_WIDTH-1:0] stable_count = {COUNT_WIDTH{1'b0}};

    always @(posedge clk) begin
        button_sync <= {button_sync[0], button_in};
        if (button_sync[1] == button_pressed) begin
            stable_count <= {COUNT_WIDTH{1'b0}};
        end else if (stable_count >= STABLE_CYCLES - 1) begin
            button_pressed <= button_sync[1];
            stable_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            stable_count <= stable_count + 1'b1;
        end
    end
endmodule
