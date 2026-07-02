module alu (
    input  logic [31:0] a,            // first operand
    input  logic [31:0] b,            // second operand (register OR immediate)
    input  logic [3:0]  alu_op,       // operation selector
    output logic [31:0] result,       // result of the operation
    output logic        zero          // 1 when result == 0 (for branches)
);
    logic [4:0] shamt;
    assign shamt = b[4:0];

    always_comb begin
        case (alu_op)
            4'b0000: result = a + b;                                         // ADD
            4'b0001: result = a - b;                                         // SUB
            4'b0010: result = a & b;                                         // AND
            4'b0011: result = a | b;                                         // OR
            4'b0100: result = a ^ b;                                         // XOR
            4'b0101: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;     // SLT
            4'b0110: result = ($unsigned(a) < $unsigned(b)) ? 32'd1 : 32'd0; // SLTU
            4'b0111: result = a << shamt;                                    // SLL  / SLLI
            4'b1000: result = a >> shamt;                                    // SRL  / SRLI
            4'b1001: result = $signed(a) >>> shamt;                          // SRA  / SRAI
            4'b1010: result = b;                                             // PASS-B (LUI)
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule