//=============================================================================
// tb_decoder.v  -  unit test for decoder
// Walks through every opcode and checks the register addresses, immediate
// extension and the full ctrl bundle, including the special cases:
//   st  -> stored register comes out on rs2, no reg write
//   ret -> implicit read of r15
//   call-> implicit write of r15
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_decoder;
  `TB_INIT
  `include "tb_encode.vh"

  reg  [31:0]        instr;
  wire [3:0]         rd_addr, rs1_addr, rs2_addr;
  wire [31:0]        imm_ext;
  wire [26:0]        branch_offset;
  wire [`CTRL_W-1:0] ctrl;

  decoder dut (
    .instr(instr), .rd_addr(rd_addr), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
    .imm_ext(imm_ext), .branch_offset(branch_offset), .ctrl(ctrl)
  );

  reg [`CTRL_W-1:0] exp;
  reg [4:0]         alu_ops [0:9];
  reg [3:0]         alu_exp [0:9];
  integer           i;

  initial begin
    $display("tb_decoder");

    alu_ops[0] = `OP_ADD; alu_exp[0] = `ALU_ADD;
    alu_ops[1] = `OP_SUB; alu_exp[1] = `ALU_SUB;
    alu_ops[2] = `OP_MUL; alu_exp[2] = `ALU_MUL;
    alu_ops[3] = `OP_DIV; alu_exp[3] = `ALU_DIV;
    alu_ops[4] = `OP_MOD; alu_exp[4] = `ALU_MOD;
    alu_ops[5] = `OP_AND; alu_exp[5] = `ALU_AND;
    alu_ops[6] = `OP_OR;  alu_exp[6] = `ALU_OR;
    alu_ops[7] = `OP_LSL; alu_exp[7] = `ALU_LSL;
    alu_ops[8] = `OP_LSR; alu_exp[8] = `ALU_LSR;
    alu_ops[9] = `OP_ASR; alu_exp[9] = `ALU_ASR;

    // ---- 3-address ALU ops, register form ----------------------------
    // (index in the messages: 0=add 1=sub 2=mul 3=div 4=mod 5=and 6=or
    //  7=lsl 8=lsr 9=asr)
    for (i = 0; i < 10; i = i + 1) begin
      instr = enc_r(alu_ops[i], 4'd1, 4'd2, 4'd3);
      #1;
      exp = `CTRL_BUBBLE;
      exp[`C_REG_WRITE] = 1; exp[`C_RS1_VALID] = 1; exp[`C_RS2_VALID] = 1;
      exp[`C_ALU_OP] = alu_exp[i];
      `CHECK_EQ_I(rd_addr,  4'd1, "alu reg form: rd", i)
      `CHECK_EQ_I(rs1_addr, 4'd2, "alu reg form: rs1", i)
      `CHECK_EQ_I(rs2_addr, 4'd3, "alu reg form: rs2", i)
      `CHECK_EQ_I(ctrl, exp, "alu reg form: ctrl", i)
    end

    // ---- 3-address ALU ops, immediate form ---------------------------
    for (i = 0; i < 10; i = i + 1) begin
      instr = enc_i(alu_ops[i], 4'd4, 4'd5, 16'd100, 2'b00);
      #1;
      exp = `CTRL_BUBBLE;
      exp[`C_REG_WRITE] = 1; exp[`C_RS1_VALID] = 1; exp[`C_ALU_SRC_IMM] = 1;
      exp[`C_ALU_OP] = alu_exp[i];
      `CHECK_EQ_I(rd_addr,  4'd4,    "alu imm form: rd", i)
      `CHECK_EQ_I(rs1_addr, 4'd5,    "alu imm form: rs1", i)
      `CHECK_EQ_I(imm_ext,  32'd100, "alu imm form: imm", i)
      `CHECK_EQ_I(ctrl, exp, "alu imm form: ctrl (rs2_valid must be 0)", i)
    end

    // ---- immediate modifiers -----------------------------------------
    instr = enc_i(`OP_ADD, 1, 2, 16'hFFFD, 2'b00); #1
    `CHECK_EQ(imm_ext, 32'hFFFF_FFFD, "default modifier sign-extends (-3)")
    instr = enc_i(`OP_ADD, 1, 2, 16'h7FFF, 2'b00); #1
    `CHECK_EQ(imm_ext, 32'h0000_7FFF, "default modifier, positive max")
    instr = enc_i(`OP_ADD, 1, 2, 16'hFFFD, 2'b01); #1
    `CHECK_EQ(imm_ext, 32'h0000_FFFD, "'u' modifier zero-extends")
    instr = enc_i(`OP_MOV, 1, 0, 16'hABCD, 2'b10); #1
    `CHECK_EQ(imm_ext, 32'hABCD_0000, "'h' modifier loads upper half")
    instr = enc_i(`OP_ADD, 1, 2, 16'h1234, 2'b11); #1
    `CHECK_EQ(imm_ext, 32'h0, "reserved modifier 11 gives 0")

    // ---- cmp ---------------------------------------------------------
    instr = enc_r(`OP_CMP, 4'd0, 4'd6, 4'd7); #1
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1; exp[`C_RS2_VALID] = 1; exp[`C_FLAGS_WRITE] = 1;
    exp[`C_ALU_OP] = `ALU_CMP;
    `CHECK_EQ(rs1_addr, 4'd6, "cmp: rs1")
    `CHECK_EQ(rs2_addr, 4'd7, "cmp: rs2")
    `CHECK_EQ(ctrl, exp, "cmp reg form: ctrl (no reg write, sets flags)")

    instr = enc_i(`OP_CMP, 4'd0, 4'd6, 16'd9, 2'b00); #1
    exp[`C_RS2_VALID] = 0; exp[`C_ALU_SRC_IMM] = 1;
    `CHECK_EQ(ctrl, exp, "cmp imm form: ctrl")

    // ---- not / mov (source in rs2 field) -----------------------------
    instr = enc_r(`OP_NOT, 4'd3, 4'd0, 4'd4); #1
    exp = `CTRL_BUBBLE;
    exp[`C_REG_WRITE] = 1; exp[`C_RS2_VALID] = 1; exp[`C_ALU_OP] = `ALU_NOT;
    `CHECK_EQ(rd_addr,  4'd3, "not: rd")
    `CHECK_EQ(rs2_addr, 4'd4, "not: source on rs2")
    `CHECK_EQ(ctrl, exp, "not reg form: ctrl (rs1 not read)")

    instr = enc_r(`OP_MOV, 4'd9, 4'd0, 4'd10); #1
    exp[`C_ALU_OP] = `ALU_MOV;
    `CHECK_EQ(rd_addr,  4'd9,  "mov: rd")
    `CHECK_EQ(rs2_addr, 4'd10, "mov: source on rs2")
    `CHECK_EQ(ctrl, exp, "mov reg form: ctrl")

    instr = enc_i(`OP_MOV, 4'd9, 4'd0, 16'd42, 2'b00); #1
    exp[`C_RS2_VALID] = 0; exp[`C_ALU_SRC_IMM] = 1;
    `CHECK_EQ(imm_ext, 32'd42, "mov imm: immediate")
    `CHECK_EQ(ctrl, exp, "mov imm form: ctrl")

    // ---- ld rd, imm[rs1] ---------------------------------------------
    instr = enc_i(`OP_LD, 4'd1, 4'd2, 16'd8, 2'b00); #1
    exp = `CTRL_BUBBLE;
    exp[`C_REG_WRITE] = 1; exp[`C_RS1_VALID] = 1; exp[`C_MEM_READ] = 1;
    exp[`C_MEM_TO_REG] = 1; exp[`C_ALU_SRC_IMM] = 1; exp[`C_ALU_OP] = `ALU_ADD;
    `CHECK_EQ(rd_addr,  4'd1,  "ld: rd")
    `CHECK_EQ(rs1_addr, 4'd2,  "ld: base register")
    `CHECK_EQ(imm_ext,  32'd8, "ld: offset")
    `CHECK_EQ(ctrl, exp, "ld: ctrl")

    // ---- st rd, imm[rs1]: rd is a SOURCE --------------------------------
    instr = enc_i(`OP_ST, 4'd6, 4'd7, 16'hFFFC, 2'b00); #1
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1; exp[`C_RS2_VALID] = 1; exp[`C_MEM_WRITE] = 1;
    exp[`C_ALU_SRC_IMM] = 1; exp[`C_ALU_OP] = `ALU_ADD;
    `CHECK_EQ(rs1_addr, 4'd7, "st: base register on rs1")
    `CHECK_EQ(rs2_addr, 4'd6, "st: stored register moved to rs2")
    `CHECK_EQ(imm_ext,  32'hFFFF_FFFC, "st: negative offset")
    `CHECK_EQ(ctrl, exp, "st: ctrl (no reg write)")

    // ---- b -----------------------------------------------------------
    instr = enc_b(`OP_B, 27'h7FF_FFFE); #1
    exp = `CTRL_BUBBLE;
    exp[`C_JUMP] = 1;
    `CHECK_EQ(branch_offset, 27'h7FF_FFFE, "b: offset field")
    `CHECK_EQ(ctrl, exp, "b: ctrl")

    // ---- call: implicit write of ra ----------------------------------
    instr = enc_b(`OP_CALL, 27'd12); #1
    exp = `CTRL_BUBBLE;
    exp[`C_JUMP] = 1; exp[`C_IS_CALL] = 1; exp[`C_REG_WRITE] = 1;
    `CHECK_EQ(rd_addr, `REG_RA, "call: rd forced to ra (r15)")
    `CHECK_EQ(branch_offset, 27'd12, "call: offset field")
    `CHECK_EQ(ctrl, exp, "call: ctrl")

    // ---- beq / bgt ---------------------------------------------------
    instr = enc_b(`OP_BEQ, 27'd3); #1
    exp = `CTRL_BUBBLE;
    exp[`C_BRANCH] = 1;
    `CHECK_EQ(ctrl, exp, "beq: ctrl (branch_gt clear)")
    `CHECK_EQ(branch_offset, 27'd3, "beq: offset field")

    instr = enc_b(`OP_BGT, 27'd5); #1
    exp[`C_BRANCH_GT] = 1;
    `CHECK_EQ(ctrl, exp, "bgt: ctrl (branch_gt set)")
    `CHECK_EQ(branch_offset, 27'd5, "bgt: offset field")

    // ---- ret: implicit read of ra -------------------------------------
    instr = {`OP_RET, 27'b0}; #1
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1; exp[`C_IS_RET] = 1;
    `CHECK_EQ(rs1_addr, `REG_RA, "ret: rs1 forced to ra (r15)")
    `CHECK_EQ(ctrl, exp, "ret: ctrl")

    // ---- nop / illegal ------------------------------------------------
    instr = `NOP_INSTR; #1
    `CHECK_EQ(ctrl, `CTRL_BUBBLE, "nop: ctrl is a bubble")
    instr = {5'b11111, 27'h5A5A5A5}; #1
    `CHECK_EQ(ctrl, `CTRL_BUBBLE, "illegal opcode decodes as a bubble")
    instr = {5'b10101, 27'h0}; #1
    `CHECK_EQ(ctrl, `CTRL_BUBBLE, "unused opcode 10101 decodes as a bubble")

    `TB_FINISH
  end
endmodule
