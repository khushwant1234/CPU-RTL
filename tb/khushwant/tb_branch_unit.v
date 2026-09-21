//=============================================================================
// tb_branch_unit.v  -  unit test for branch_unit
// Exhaustive over all control/flag combinations, plus target selection.
//=============================================================================
`timescale 1ns/1ps
`include "tb_check.vh"

module tb_branch_unit;
  `TB_INIT

  reg         jump, branch, branch_gt, is_ret, flag_e, flag_gt;
  reg  [31:0] branch_target = 32'h0000_1000, ret_addr = 32'h0000_2000;
  wire        branch_taken;
  wire [31:0] branch_pc;

  branch_unit dut (
    .jump(jump), .branch(branch), .branch_gt(branch_gt), .is_ret(is_ret),
    .flag_e(flag_e), .flag_gt(flag_gt), .branch_target(branch_target),
    .ret_addr(ret_addr), .branch_taken(branch_taken), .branch_pc(branch_pc)
  );

  integer v;
  reg     exp_taken;

  initial begin
    $display("tb_branch_unit");

    // all 64 input combinations against the expected equation
    // (index = {jump, branch, branch_gt, is_ret, flag_e, flag_gt})
    for (v = 0; v < 64; v = v + 1) begin
      {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = v[5:0];
      exp_taken = jump | is_ret | (branch & (branch_gt ? flag_gt : flag_e));
      #1
      `CHECK_EQ_I(branch_taken, exp_taken, "taken for input combo", v)
      `CHECK_EQ_I(branch_pc, is_ret ? ret_addr : branch_target, "target for input combo", v)
    end

    // readable directed cases
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b000000; #1
    `CHECK_EQ(branch_taken, 1'b0, "normal instruction not taken")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b100000; #1
    `CHECK_EQ(branch_taken, 1'b1, "b always taken")
    `CHECK_EQ(branch_pc, 32'h1000, "b goes to branch_target")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b010010; #1
    `CHECK_EQ(branch_taken, 1'b1, "beq taken when E=1")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b010001; #1
    `CHECK_EQ(branch_taken, 1'b0, "beq not taken when only GT=1")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b011001; #1
    `CHECK_EQ(branch_taken, 1'b1, "bgt taken when GT=1")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b011010; #1
    `CHECK_EQ(branch_taken, 1'b0, "bgt not taken when only E=1")
    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b000100; #1
    `CHECK_EQ(branch_taken, 1'b1, "ret always taken")
    `CHECK_EQ(branch_pc, 32'h2000, "ret goes to ra")

    `TB_FINISH
  end
endmodule
