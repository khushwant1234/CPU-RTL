//=============================================================================
// tb_decoder.sv  -  unit test for decoder
// Walks through every opcode and checks the register addresses, immediate
// extension and the full ctrl bundle, including the special cases:
//   st  -> stored register comes out on rs2, no reg write
//   ret -> implicit read of r15
//   call-> implicit write of r15
//=============================================================================
`timescale 1ns/1ps
module tb_decoder;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `include "tb_encode.svh"
  `TB_INIT

  logic [31:0] instr;
  logic [3:0]  rd_addr, rs1_addr, rs2_addr;
  logic [31:0] imm_ext;
  logic [26:0] branch_offset;
  ctrl_t       ctrl;

  decoder dut (.*);

  ctrl_t exp;

  function automatic ctrl_t bubble();
    ctrl_t c = '0;
    c.alu_op = ALU_NOP;
    return c;
  endfunction

  task automatic check_regs(string name, logic [3:0] rd, logic [3:0] rs1, logic [3:0] rs2);
    `CHECK_EQ(rd_addr,  rd,  {name, ": rd_addr"})
    `CHECK_EQ(rs1_addr, rs1, {name, ": rs1_addr"})
    `CHECK_EQ(rs2_addr, rs2, {name, ": rs2_addr"})
  endtask

  opcode_e alu_ops [10] = '{OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD,
                            OP_AND, OP_OR,  OP_LSL, OP_LSR, OP_ASR};
  alu_op_e alu_exp [10] = '{ALU_ADD, ALU_SUB, ALU_MUL, ALU_DIV, ALU_MOD,
                            ALU_AND, ALU_OR,  ALU_LSL, ALU_LSR, ALU_ASR};
  string   op_name [10] = '{"add", "sub", "mul", "div", "mod",
                            "and", "or",  "lsl", "lsr", "asr"};

  initial begin
    $display("tb_decoder");

    // ---- 3-address ALU ops, register form ----------------------------
    foreach (alu_ops[i]) begin
      instr = enc_r(alu_ops[i], 4'd1, 4'd2, 4'd3);
      #1;
      exp = bubble();
      exp.reg_write_en = 1; exp.rs1_valid = 1; exp.rs2_valid = 1;
      exp.alu_op = alu_exp[i];
      check_regs(op_name[i], 4'd1, 4'd2, 4'd3);
      `CHECK_EQ(ctrl, exp, {op_name[i], " reg form: ctrl"})
    end

    // ---- 3-address ALU ops, immediate form ---------------------------
    foreach (alu_ops[i]) begin
      instr = enc_i(alu_ops[i], 4'd4, 4'd5, 16'd100);
      #1;
      exp = bubble();
      exp.reg_write_en = 1; exp.rs1_valid = 1; exp.alu_src_imm = 1;
      exp.alu_op = alu_exp[i];
      `CHECK_EQ(rd_addr,  4'd4, {op_name[i], " imm form: rd"})
      `CHECK_EQ(rs1_addr, 4'd5, {op_name[i], " imm form: rs1"})
      `CHECK_EQ(imm_ext,  32'd100, {op_name[i], " imm form: imm"})
      `CHECK_EQ(ctrl, exp, {op_name[i], " imm form: ctrl (rs2_valid must be 0)"})
    end

    // ---- immediate modifiers -----------------------------------------
    instr = enc_i(OP_ADD, 1, 2, 16'hFFFD, 2'b00); #1
    `CHECK_EQ(imm_ext, 32'hFFFF_FFFD, "default modifier sign-extends (-3)")
    instr = enc_i(OP_ADD, 1, 2, 16'h7FFF, 2'b00); #1
    `CHECK_EQ(imm_ext, 32'h0000_7FFF, "default modifier, positive max")
    instr = enc_i(OP_ADD, 1, 2, 16'hFFFD, 2'b01); #1
    `CHECK_EQ(imm_ext, 32'h0000_FFFD, "'u' modifier zero-extends")
    instr = enc_i(OP_MOV, 1, 0, 16'hABCD, 2'b10); #1
    `CHECK_EQ(imm_ext, 32'hABCD_0000, "'h' modifier loads upper half")
    instr = enc_i(OP_ADD, 1, 2, 16'h1234, 2'b11); #1
    `CHECK_EQ(imm_ext, 32'h0, "reserved modifier 11 gives 0")

    // ---- cmp ---------------------------------------------------------
    instr = enc_r(OP_CMP, 4'd0, 4'd6, 4'd7); #1
    exp = bubble();
    exp.rs1_valid = 1; exp.rs2_valid = 1; exp.flags_write_en = 1; exp.alu_op = ALU_CMP;
    `CHECK_EQ(rs1_addr, 4'd6, "cmp: rs1")
    `CHECK_EQ(rs2_addr, 4'd7, "cmp: rs2")
    `CHECK_EQ(ctrl, exp, "cmp reg form: ctrl (no reg write, sets flags)")

    instr = enc_i(OP_CMP, 4'd0, 4'd6, 16'd9); #1
    exp.rs2_valid = 0; exp.alu_src_imm = 1;
    `CHECK_EQ(ctrl, exp, "cmp imm form: ctrl")

    // ---- not / mov (source in rs2 field) -----------------------------
    instr = enc_r(OP_NOT, 4'd3, 4'd0, 4'd4); #1
    exp = bubble();
    exp.reg_write_en = 1; exp.rs2_valid = 1; exp.alu_op = ALU_NOT;
    check_regs("not", 4'd3, 4'd0, 4'd4);
    `CHECK_EQ(ctrl, exp, "not reg form: ctrl (rs1 not read)")

    instr = enc_r(OP_MOV, 4'd9, 4'd0, 4'd10); #1
    exp.alu_op = ALU_MOV;
    `CHECK_EQ(rd_addr,  4'd9,  "mov: rd")
    `CHECK_EQ(rs2_addr, 4'd10, "mov: source on rs2")
    `CHECK_EQ(ctrl, exp, "mov reg form: ctrl")

    instr = enc_i(OP_MOV, 4'd9, 4'd0, 16'd42); #1
    exp.rs2_valid = 0; exp.alu_src_imm = 1;
    `CHECK_EQ(imm_ext, 32'd42, "mov imm: immediate")
    `CHECK_EQ(ctrl, exp, "mov imm form: ctrl")

    // ---- ld rd, imm[rs1] ---------------------------------------------
    instr = enc_i(OP_LD, 4'd1, 4'd2, 16'd8); #1
    exp = bubble();
    exp.reg_write_en = 1; exp.rs1_valid = 1; exp.mem_read_en = 1;
    exp.mem_to_reg = 1; exp.alu_src_imm = 1; exp.alu_op = ALU_ADD;
    `CHECK_EQ(rd_addr,  4'd1, "ld: rd")
    `CHECK_EQ(rs1_addr, 4'd2, "ld: base register")
    `CHECK_EQ(imm_ext,  32'd8, "ld: offset")
    `CHECK_EQ(ctrl, exp, "ld: ctrl")

    // ---- st rd, imm[rs1]: rd is a SOURCE --------------------------------
    instr = enc_i(OP_ST, 4'd6, 4'd7, 16'hFFFC); #1
    exp = bubble();
    exp.rs1_valid = 1; exp.rs2_valid = 1; exp.mem_write_en = 1;
    exp.alu_src_imm = 1; exp.alu_op = ALU_ADD;
    `CHECK_EQ(rs1_addr, 4'd7, "st: base register on rs1")
    `CHECK_EQ(rs2_addr, 4'd6, "st: stored register moved to rs2")
    `CHECK_EQ(imm_ext,  32'hFFFF_FFFC, "st: negative offset")
    `CHECK_EQ(ctrl, exp, "st: ctrl (no reg write)")

    // ---- b -----------------------------------------------------------
    instr = enc_b(OP_B, 27'h7FF_FFFE); #1
    exp = bubble();
    exp.jump = 1;
    `CHECK_EQ(branch_offset, 27'h7FF_FFFE, "b: offset field")
    `CHECK_EQ(ctrl, exp, "b: ctrl")

    // ---- call: implicit write of ra ----------------------------------
    instr = enc_b(OP_CALL, 27'd12); #1
    exp = bubble();
    exp.jump = 1; exp.is_call = 1; exp.reg_write_en = 1;
    `CHECK_EQ(rd_addr, REG_RA, "call: rd forced to ra (r15)")
    `CHECK_EQ(branch_offset, 27'd12, "call: offset field")
    `CHECK_EQ(ctrl, exp, "call: ctrl")

    // ---- beq / bgt ---------------------------------------------------
    instr = enc_b(OP_BEQ, 27'd3); #1
    exp = bubble();
    exp.branch = 1;
    `CHECK_EQ(ctrl, exp, "beq: ctrl")
    `CHECK_EQ(branch_offset, 27'd3, "beq: offset field")

    instr = enc_b(OP_BGT, 27'd5); #1
    `CHECK_EQ(ctrl.branch, 1'b1, "bgt: branch bit")
    `CHECK_EQ(ctrl.reg_write_en, 1'b0, "bgt: no reg write")

    // ---- ret: implicit read of ra -------------------------------------
    instr = {OP_RET, 27'b0}; #1
    exp = bubble();
    exp.rs1_valid = 1; exp.is_ret = 1;
    `CHECK_EQ(rs1_addr, REG_RA, "ret: rs1 forced to ra (r15)")
    `CHECK_EQ(ctrl, exp, "ret: ctrl")

    // ---- nop / illegal ------------------------------------------------
    instr = NOP_INSTR; #1
    `CHECK_EQ(ctrl, bubble(), "nop: ctrl is a bubble")
    instr = {5'b11111, 27'h5A5A5A5}; #1
    `CHECK_EQ(ctrl, bubble(), "illegal opcode decodes as a bubble")
    instr = {5'b10101, 27'h0}; #1
    `CHECK_EQ(ctrl, bubble(), "unused opcode 10101 decodes as a bubble")

    `TB_FINISH
  end
endmodule
