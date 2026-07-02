module control (
    input  logic [6:0] opcode,         // 7-bit opcode from instruction
    input  logic [2:0] funct3,         // 3-bit funct3 from instruction
    input  logic [6:0] funct7,         // 7-bit funct7 from instruction
    output logic       reg_write_en,   // 1 when writing to register file
    output logic       alu_src,        // 1 when ALU second operand is immediate, 0 when it's from register
    output logic       mem_write,      // 1 when writing to memory
    output logic       mem_read,       // 1 when reading from memory
    output logic       branch,         // 1 when instruction is a branch
    output logic [3:0] alu_op,          // 4-bit ALU operation code
    output logic [1:0] pc_src,          // 2-bit program counter source selector
    output logic [1:0] wb_src,          // 2-bit write-back source selector
    output logic alu_a_src       // 1-bit ALU first operand source selector
);
    // Define opcode values for different instruction types
    localparam [6:0] OPCODE_R_TYPE = 7'b0110011;
    localparam [6:0] OPCODE_I_TYPE = 7'b0010011;
    localparam [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam [6:0] OPCODE_STORE  = 7'b0100011;
    localparam [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam [6:0] OPCODE_JAL    = 7'b1101111;
    localparam [6:0] OPCODE_JALR   = 7'b1100111;
    localparam [6:0] OPCODE_LUI    = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC  = 7'b0010111;

    // Define ALU operation codes
    logic [1:0] alu_decode_mode;
    localparam [1:0] ALU_ADD  = 2'b00;
    localparam [1:0] ALU_SUB  = 2'b01;
    localparam [1:0] ALU_FUNC = 2'b10;
    localparam [1:0] ALU_LUI  = 2'b11;

    // Control logic
    always_comb begin
        reg_write_en    = 1'b0;
        alu_src         = 1'b0;
        mem_write       = 1'b0;
        mem_read        = 1'b0;
        branch          = 1'b0;
        wb_src          = 2'b00;
        pc_src          = 2'b00;
        alu_a_src       = 1'b0;
        alu_decode_mode = ALU_ADD;

        case (opcode)
            OPCODE_R_TYPE: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b0;
                alu_decode_mode = ALU_FUNC;
            end
            OPCODE_I_TYPE: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_FUNC;
            end
            OPCODE_LOAD: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                mem_read        = 1'b1;
                wb_src          = 2'b01;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_STORE: begin
                alu_src         = 1'b1;
                mem_write       = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_BRANCH: begin
                alu_src         = 1'b0;
                branch          = 1'b1;
                pc_src          = 2'b01;
                alu_decode_mode = ALU_SUB;
            end
            OPCODE_JAL: begin
                reg_write_en    = 1'b1;
                wb_src          = 2'b10;
                pc_src          = 2'b11;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_JALR: begin
                reg_write_en    = 1'b1;
                wb_src          = 2'b10;
                pc_src          = 2'b10;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_LUI: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_LUI;
            end
            OPCODE_AUIPC: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_a_src       = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            default: begin
                reg_write_en    = 1'b0;
                alu_src         = 1'b0;
                mem_write       = 1'b0;
                mem_read        = 1'b0;
                branch          = 1'b0;
                wb_src          = 2'b00;
                pc_src          = 2'b00;
                alu_a_src       = 1'b0;
                alu_decode_mode = ALU_ADD;
            end
        endcase
    end
    // ALU operation decoding based on funct3 and funct7
    always_comb begin
        case (alu_decode_mode)
            ALU_ADD: alu_op = 4'b0000;
            ALU_SUB: alu_op = 4'b0001;
            ALU_FUNC: begin
                case (funct3)
                    3'b000: alu_op = (opcode == OPCODE_R_TYPE && funct7[5]) ? 4'b0001 : 4'b0000;
                    3'b111: alu_op = 4'b0010;
                    3'b110: alu_op = 4'b0011;
                    3'b100: alu_op = 4'b0100;
                    3'b010: alu_op = 4'b0101;
                    3'b011: alu_op = 4'b0110;
                    3'b001: alu_op = 4'b0111;
                    3'b101: alu_op = funct7[5] ? 4'b1001 : 4'b1000;
                    default: alu_op = 4'b0000;
                endcase
            end
            ALU_LUI: alu_op = 4'b1010;
            default: alu_op = 4'b0000;
        endcase
    end
endmodule