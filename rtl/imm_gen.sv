module imm_gen (
    input  logic [31:0] instr,      // the full 32-bit instruction
    output logic [31:0] imm         // 32-bit sign-extended immediate
);
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    localparam [6:0] OPCODE_I_TYPE = 7'b0010011;
    localparam [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam [6:0] OPCODE_STORE  = 7'b0100011;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_LUI    = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam [6:0] OPCODE_JAL    = 7'b1101111;
    localparam [6:0] OPCODE_JALR   = 7'b1100111;


    always_comb begin
        case (opcode)
            OPCODE_I_TYPE, OPCODE_LOAD: begin
                imm = {{20{instr[31]}}, instr[31:20]}; // I-type immediate
            end
            OPCODE_STORE: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type immediate
            end
            OPCODE_BRANCH: begin
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type immediate
            end
            OPCODE_LUI, OPCODE_AUIPC: begin
                imm = {instr[31:12], 12'b0}; // U-type immediate
            end
            OPCODE_JAL: begin
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type immediate
            end
            OPCODE_JALR: begin
                imm = {{20{instr[31]}}, instr[31:20]}; // I-type immediate for JALR
            end
            default: begin
                imm = 32'd0; // Default case for unsupported opcodes
            end
        endcase
    end
endmodule