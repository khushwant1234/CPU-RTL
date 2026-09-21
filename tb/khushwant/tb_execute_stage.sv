//=============================================================================
// tb_execute_stage.sv  -  unit test for execute_stage
// Checks the whole EX stage: operand mux (I bit), ALU through the stage,
// branch target calculation (positive and negative offsets), cmp -> beq/bgt
// on the following cycle, ret target, call/b, and that non-cmp instructions
// leave the flags alone.
//=============================================================================
`timescale 1ns/1ps
module tb_execute_stage;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0;
  logic [31:0] pc = 0, op1 = 0, op2 = 0, imm_ext = 0;
  logic [26:0] branch_offset = 0;
  ctrl_t       ctrl;
  logic [31:0] alu_result, branch_pc;
  logic        flag_e, flag_gt, branch_taken;

  execute_stage dut (.*);

  always #5 clk = ~clk;

  function automatic ctrl_t c_alu(alu_op_e op, logic imm);
    ctrl_t c = CTRL_BUBBLE;
    c.reg_write_en = 1; c.rs1_valid = 1; c.rs2_valid = !imm;
    c.alu_src_imm = imm; c.alu_op = op;
    return c;
  endfunction

  function automatic ctrl_t c_cmp(logic imm);
    ctrl_t c = CTRL_BUBBLE;
    c.flags_write_en = 1; c.rs1_valid = 1; c.rs2_valid = !imm;
    c.alu_src_imm = imm; c.alu_op = ALU_CMP;
    return c;
  endfunction

  function automatic ctrl_t c_br(logic gt);
    ctrl_t c = CTRL_BUBBLE;
    c.branch = 1; c.branch_gt = gt;
    return c;
  endfunction

  // run a cmp through EX for one cycle so flags get written
  task automatic do_cmp(logic [31:0] x, logic [31:0] y);
    ctrl = c_cmp(0); op1 = x; op2 = y;
    @(posedge clk); #1;
    ctrl = CTRL_BUBBLE;
  endtask

  initial begin
    $display("tb_execute_stage");
    ctrl  = CTRL_BUBBLE;
    rst_n = 0;
    #2 rst_n = 1;

    // ---- ALU through the stage --------------------------------------
    ctrl = c_alu(ALU_ADD, 0); op1 = 32'd5; op2 = 32'd7; imm_ext = 32'd100;
    #1 `CHECK_EQ(alu_result, 32'd12, "add uses op2 when I=0")
       `CHECK_EQ(branch_taken, 1'b0, "add does not branch")
    ctrl = c_alu(ALU_ADD, 1);
    #1 `CHECK_EQ(alu_result, 32'd105, "add uses imm when I=1")
    ctrl = c_alu(ALU_SUB, 1); imm_ext = 32'hFFFF_FFFF;
    #1 `CHECK_EQ(alu_result, 32'd6, "sub with -1 immediate")
    ctrl = c_alu(ALU_MOV, 1); imm_ext = 32'hABCD_0000;
    #1 `CHECK_EQ(alu_result, 32'hABCD_0000, "mov immediate (movh)")

    // ld/st address = rs1 + imm
    ctrl = c_alu(ALU_ADD, 1); ctrl.mem_read_en = 1; op1 = 32'h100; imm_ext = 32'hFFFF_FFFC;
    #1 `CHECK_EQ(alu_result, 32'hFC, "ld address with negative offset")

    // ---- flags are only written by cmp -------------------------------
    do_cmp(32'd3, 32'd3);
    `CHECK_EQ({flag_e, flag_gt}, 2'b10, "cmp equal sets E")
    ctrl = c_alu(ALU_SUB, 0); op1 = 32'd9; op2 = 32'd1;
    @(posedge clk); #1
    `CHECK_EQ({flag_e, flag_gt}, 2'b10, "sub does not touch flags")

    // ---- cmp then beq / bgt on the next cycle -------------------------
    pc = 32'h0000_0040;
    do_cmp(32'd8, 32'd8);
    ctrl = c_br(0); branch_offset = 27'd5;
    #1 `CHECK_EQ(branch_taken, 1'b1, "beq taken after equal cmp")
       `CHECK_EQ(branch_pc, 32'h0000_0054, "target = pc + 5*4")
    ctrl = c_br(1);
    #1 `CHECK_EQ(branch_taken, 1'b0, "bgt not taken after equal cmp")

    do_cmp(32'd10, -32'sd2);
    ctrl = c_br(1); branch_offset = -27'sd4;
    #1 `CHECK_EQ(branch_taken, 1'b1, "bgt taken, 10 > -2 signed")
       `CHECK_EQ(branch_pc, 32'h0000_0030, "backward target = pc - 4*4")
    ctrl = c_br(0);
    #1 `CHECK_EQ(branch_taken, 1'b0, "beq not taken when not equal")

    // cmp with immediate
    ctrl = c_cmp(1); op1 = 32'd20; imm_ext = 32'd20;
    @(posedge clk); #1;
    ctrl = c_br(0);
    #1 `CHECK_EQ(branch_taken, 1'b1, "cmp with immediate then beq")

    // ---- unconditional ------------------------------------------------
    ctrl = CTRL_BUBBLE; ctrl.jump = 1; pc = 32'h200; branch_offset = 27'd0;
    #1 `CHECK_EQ(branch_taken, 1'b1, "b taken")
       `CHECK_EQ(branch_pc, 32'h200, "b with offset 0 loops on itself")
    ctrl.is_call = 1; ctrl.reg_write_en = 1; branch_offset = 27'd16;
    #1 `CHECK_EQ(branch_taken, 1'b1, "call taken")
       `CHECK_EQ(branch_pc, 32'h240, "call target")

    ctrl = CTRL_BUBBLE; ctrl.is_ret = 1; ctrl.rs1_valid = 1; op1 = 32'h0000_0124;
    #1 `CHECK_EQ(branch_taken, 1'b1, "ret taken")
       `CHECK_EQ(branch_pc, 32'h124, "ret jumps to op1 (ra)")

    // bubble does nothing
    ctrl = CTRL_BUBBLE;
    #1 `CHECK_EQ(branch_taken, 1'b0, "bubble does not branch")
       `CHECK_EQ(alu_result, 32'd0, "bubble alu result is 0")

    `TB_FINISH
  end
endmodule
