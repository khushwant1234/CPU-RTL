//=============================================================================
// tb_execute_stage.v  -  unit test for execute_stage
// Checks the whole EX stage: operand mux (I bit), ALU through the stage,
// branch target calculation (positive and negative offsets), cmp -> beq/bgt
// on the following cycle, ret target, call/b, and that non-cmp instructions
// leave the flags alone.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_execute_stage;
  `TB_INIT

  reg                clk = 0;
  reg                rst_n;
  reg  [31:0]        pc = 0, op1 = 0, op2 = 0, imm_ext = 0;
  reg  [26:0]        branch_offset = 0;
  reg  [`CTRL_W-1:0] ctrl;
  wire [31:0]        alu_result, branch_pc;
  wire               flag_e, flag_gt, branch_taken;

  execute_stage dut (
    .clk(clk), .rst_n(rst_n), .pc(pc), .op1(op1), .op2(op2), .imm_ext(imm_ext),
    .branch_offset(branch_offset), .ctrl(ctrl), .alu_result(alu_result),
    .flag_e(flag_e), .flag_gt(flag_gt), .branch_taken(branch_taken), .branch_pc(branch_pc)
  );

  always #5 clk = ~clk;

  // ctrl for an ALU instruction, I bit = imm
  function [`CTRL_W-1:0] c_alu;
    input [3:0] op;
    input       imm;
    begin
      c_alu = `CTRL_BUBBLE;
      c_alu[`C_REG_WRITE]   = 1;
      c_alu[`C_RS1_VALID]   = 1;
      c_alu[`C_RS2_VALID]   = !imm;
      c_alu[`C_ALU_SRC_IMM] = imm;
      c_alu[`C_ALU_OP]      = op;
    end
  endfunction

  function [`CTRL_W-1:0] c_cmp;
    input imm;
    begin
      c_cmp = `CTRL_BUBBLE;
      c_cmp[`C_FLAGS_WRITE] = 1;
      c_cmp[`C_RS1_VALID]   = 1;
      c_cmp[`C_RS2_VALID]   = !imm;
      c_cmp[`C_ALU_SRC_IMM] = imm;
      c_cmp[`C_ALU_OP]      = `ALU_CMP;
    end
  endfunction

  function [`CTRL_W-1:0] c_br;
    input gt;
    begin
      c_br = `CTRL_BUBBLE;
      c_br[`C_BRANCH]    = 1;
      c_br[`C_BRANCH_GT] = gt;
    end
  endfunction

  // run a cmp through EX for one cycle so flags get written
  task do_cmp;
    input [31:0] x, y;
    begin
      ctrl = c_cmp(0); op1 = x; op2 = y;
      @(posedge clk); #1;
      ctrl = `CTRL_BUBBLE;
    end
  endtask

  initial begin
    $display("tb_execute_stage");
    ctrl  = `CTRL_BUBBLE;
    rst_n = 0;
    #2 rst_n = 1;

    // ---- ALU through the stage --------------------------------------
    ctrl = c_alu(`ALU_ADD, 0); op1 = 32'd5; op2 = 32'd7; imm_ext = 32'd100;
    #1 `CHECK_EQ(alu_result, 32'd12, "add uses op2 when I=0")
       `CHECK_EQ(branch_taken, 1'b0, "add does not branch")
    ctrl = c_alu(`ALU_ADD, 1);
    #1 `CHECK_EQ(alu_result, 32'd105, "add uses imm when I=1")
    ctrl = c_alu(`ALU_SUB, 1); imm_ext = 32'hFFFF_FFFF;
    #1 `CHECK_EQ(alu_result, 32'd6, "sub with -1 immediate")
    ctrl = c_alu(`ALU_MOV, 1); imm_ext = 32'hABCD_0000;
    #1 `CHECK_EQ(alu_result, 32'hABCD_0000, "mov immediate (movh)")

    // ld/st address = rs1 + imm
    ctrl = c_alu(`ALU_ADD, 1); ctrl[`C_MEM_READ] = 1; op1 = 32'h100; imm_ext = 32'hFFFF_FFFC;
    #1 `CHECK_EQ(alu_result, 32'hFC, "ld address with negative offset")

    // ---- flags are only written by cmp -------------------------------
    do_cmp(32'd3, 32'd3);
    `CHECK_EQ({flag_e, flag_gt}, 2'b10, "cmp equal sets E")
    ctrl = c_alu(`ALU_SUB, 0); op1 = 32'd9; op2 = 32'd1;
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
    ctrl = `CTRL_BUBBLE; ctrl[`C_JUMP] = 1; pc = 32'h200; branch_offset = 27'd0;
    #1 `CHECK_EQ(branch_taken, 1'b1, "b taken")
       `CHECK_EQ(branch_pc, 32'h200, "b with offset 0 loops on itself")
    ctrl[`C_IS_CALL] = 1; ctrl[`C_REG_WRITE] = 1; branch_offset = 27'd16;
    #1 `CHECK_EQ(branch_taken, 1'b1, "call taken")
       `CHECK_EQ(branch_pc, 32'h240, "call target")

    ctrl = `CTRL_BUBBLE; ctrl[`C_IS_RET] = 1; ctrl[`C_RS1_VALID] = 1; op1 = 32'h0000_0124;
    #1 `CHECK_EQ(branch_taken, 1'b1, "ret taken")
       `CHECK_EQ(branch_pc, 32'h124, "ret jumps to op1 (ra)")

    // bubble does nothing
    ctrl = `CTRL_BUBBLE;
    #1 `CHECK_EQ(branch_taken, 1'b0, "bubble does not branch")
       `CHECK_EQ(alu_result, 32'd0, "bubble alu result is 0")

    `TB_FINISH
  end
endmodule
