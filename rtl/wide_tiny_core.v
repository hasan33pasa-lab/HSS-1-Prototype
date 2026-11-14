// Separate 16-bit datapath used by the wide16 lab top; the 8-bit baseline
// remains available as an independent profile.
module wide_tiny_core (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        run_enable,
    input  wire [15:0] instruction,
    output reg  [7:0]  pc,
    output wire [15:0] debug_r2,
    output reg  [15:0] result,
    output reg  [15:0] retired_count,
    output reg         halted
);
    reg [15:0] registers [0:3];
    reg [15:0] data_memory [0:15];
    integer i;

    wire [3:0] opcode = instruction[15:12];
    wire [1:0] destination = instruction[11:10];
    wire [1:0] source = instruction[9:8];
    wire [7:0] immediate = instruction[7:0];
    wire [3:0] memory_address = instruction[3:0];

    assign debug_r2 = registers[2];

    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 8'd0;
            result <= 16'd0;
            retired_count <= 16'd0;
            halted <= 1'b0;
            for (i = 0; i < 4; i = i + 1)
                registers[i] <= 16'd0;
            for (i = 0; i < 16; i = i + 1)
                data_memory[i] <= 16'd0;
        end else if (!halted && run_enable) begin
            retired_count <= retired_count + 16'd1;
            case (opcode)
                4'h0: pc <= pc + 8'd1; // NOP
                4'h1: begin registers[destination] <= {8'd0, immediate}; pc <= pc + 8'd1; end // LDI
                4'h2: begin registers[destination] <= registers[destination] + {8'd0, immediate}; pc <= pc + 8'd1; end // ADDI
                4'h3: begin registers[destination] <= registers[destination] ^ {8'd0, immediate}; pc <= pc + 8'd1; end // XORI
                4'h4: begin result <= registers[destination]; pc <= pc + 8'd1; end // OUT
                4'h5: pc <= immediate; // JMP
                4'h6: begin // JZ checks the full 16-bit register
                    if (registers[destination] == 16'd0)
                        pc <= immediate;
                    else
                        pc <= pc + 8'd1;
                end
                4'h7: begin registers[destination] <= data_memory[memory_address]; pc <= pc + 8'd1; end // LOAD
                4'h8: begin data_memory[memory_address] <= registers[destination]; pc <= pc + 8'd1; end // STORE
                4'h9: begin registers[destination] <= registers[destination] + registers[source]; pc <= pc + 8'd1; end // ADD
                4'hA: begin registers[destination] <= registers[destination] - registers[source]; pc <= pc + 8'd1; end // SUB
                4'hB: begin registers[destination] <= registers[destination] & registers[source]; pc <= pc + 8'd1; end // AND
                4'hC: begin registers[destination] <= registers[destination] | registers[source]; pc <= pc + 8'd1; end // OR
                4'hD: begin registers[destination] <= registers[destination] ^ registers[source]; pc <= pc + 8'd1; end // XOR
                4'hE: begin registers[destination] <= registers[source]; pc <= pc + 8'd1; end // MOV
                4'hF: begin // Extended group: HALT or LDIH.
                    if (instruction[9:8] == 2'b01) begin
                        registers[destination][15:8] <= immediate;
                        pc <= pc + 8'd1;
                    end else begin
                        halted <= 1'b1; // F000 is HALT; reserved F-group words stop safely.
                    end
                end
                default: halted <= 1'b1;
            endcase
        end
    end
endmodule
