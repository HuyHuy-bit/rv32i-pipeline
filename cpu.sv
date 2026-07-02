// cpu.sv - top-level module wiring all six blocks into a single-cycle RV32I CPU.

module cpu (
    input  logic clk,
    input  logic rst,
    output logic [31:0] dbg_x1,
    output logic [31:0] dbg_x2,
    output logic [31:0] dbg_x3,
    output logic [31:0] dbg_x4,
    output logic [31:0] dbg_x5
);

    // Internal wires - one per arrow between blocks.
   logic [31:0] pc_out, next_pc, pc_plus4, branch_target, jalr_target, instr;
   logic [31:0] reg_rs1_data, reg_rs2_data, imm, alu_a, alu_b, alu_result;
   logic [31:0] mem_read_data, write_back_data;
   logic    reg_write_en, alu_src, mem_write, mem_read, branch;
   logic [3:0] alu_op;
   logic    branch_taken;
   // dedicated select signals for jumps / upper-immediates
   logic [1:0] wb_src;       // 00=alu, 01=mem, 10=pc+4
   logic [1:0] pc_src;       // 00=pc+4, 01=branch_target, 10=jalr_target
   logic       alu_a_src;    // 0=rs1, 1=pc  (AUIPC)

    // Instruction field extraction.
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    assign opcode   = instr[6:0];
    assign rd_addr  = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign funct7   = instr[31:25];

    // Program counter
    pc u_pc ( .clk(clk), .rst(rst), .next_pc(next_pc), .pc_out(pc_out) );

    // next-PC logic
    assign pc_plus4      = pc_out + 32'd4;
    assign branch_target = pc_out + imm;                 // taken branch OR jal (pc + imm)
    assign jalr_target   = (reg_rs1_data + imm) & ~32'd1; // jalr: rs1 + imm, bit 0 cleared

    branch_unit u_branch_unit (
        .rs1(reg_rs1_data),
        .rs2(reg_rs2_data),
        .funct3(funct3),
        .branch(branch),
        .pc_sel(branch_taken)
    );

    // pc_src: 00=pc+4, 01=branch (conditional), 10=jalr, 11=jal (unconditional)
    // Branches need branch_taken; jal/jalr are always taken, so no gating.
    always_comb begin
        case (pc_src)
            2'b01:   next_pc = branch_taken ? branch_target : pc_plus4; // conditional branch
            2'b10:   next_pc = jalr_target;                            // jalr
            2'b11:   next_pc = branch_target;                          // jal (pc + imm)
            default: next_pc = pc_plus4;
        endcase
    end

    // Instruction memory
    instr_mem u_instr_mem ( .addr(pc_out), .instr(instr) );

    // Control unit
    control u_control (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write_en(reg_write_en), .alu_src(alu_src),
        .mem_write(mem_write), .mem_read(mem_read),
        .branch(branch), .pc_src(pc_src), .wb_src(wb_src), .alu_a_src(alu_a_src),
        .alu_op(alu_op)
    );


    // Register file
    reg_file u_reg_file (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .rd_data(write_back_data), .rd_write_en(reg_write_en),
        .rs1_data(reg_rs1_data), .rs2_data(reg_rs2_data),
        .dbg_x1(dbg_x1), .dbg_x2(dbg_x2), .dbg_x3(dbg_x3),
        .dbg_x4(dbg_x4), .dbg_x5(dbg_x5)
    );

    // ---- Immediate Generator ----
    imm_gen u_imm_gen ( .instr(instr), .imm(imm) );

    // ---- ALU-source muxes ----
    assign alu_a = (alu_a_src) ? pc_out : reg_rs1_data;  // AUIPC uses pc as operand a
    assign alu_b = (alu_src)   ? imm    : reg_rs2_data;

    // ---- ALU ----
    alu u_alu (
        .a(alu_a), .b(alu_b), .alu_op(alu_op),
        .result(alu_result), .zero()
    );

    // ---- Data Memory ----
    data_mem u_data_mem (
        .clk(clk), .mem_write(mem_write), .mem_read(mem_read),
        .funct3(funct3),
        .addr(alu_result), .write_data(reg_rs2_data),
        .read_data(mem_read_data)
    );

    // ---- Write-back mux: ALU result, loaded value, or return address (pc+4) ----
    always_comb begin
        case (wb_src)
            2'b01:   write_back_data = mem_read_data; // loads
            2'b10:   write_back_data = pc_plus4;      // jal / jalr return address
            default: write_back_data = alu_result;    // r/i/lui/auipc
        endcase
    end

    // ---- debug taps ----
    // ---- debug taps now come from reg_file's dbg_* output ports ----
endmodule