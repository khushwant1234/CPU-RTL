//=============================================================================
// execute_stage.v
// EX stage: ALU + flags + branch resolution.
//
// op1/op2 come in AFTER the forwarding muxes (forwarding_unit in the top
// level), so this stage only works on the values it is given.
//
// Branch target (SimpleRisc): offset is a 27-bit signed count of
// instructions, target = pc + (sign_ext(offset) << 2).
//=============================================================================
`include "defines.vh"

module execute_stage (
  input  wire               clk,
  input  wire               rst_n,

  input  wire [31:0]        pc,            // pc of the instruction in EX
  input  wire [31:0]        op1,           // rs1 value (forwarded)
  input  wire [31:0]        op2,           // rs2 value (forwarded)
  input  wire [31:0]        imm_ext,
  input  wire [26:0]        branch_offset,
  input  wire [`CTRL_W-1:0] ctrl,

  output wire [31:0]        alu_result,
  output wire               flag_e,
  output wire               flag_gt,
  output wire               branch_taken,
  output wire [31:0]        branch_pc
);

  // I bit: second operand is the immediate
  wire [31:0] alu_b = ctrl[`C_ALU_SRC_IMM] ? imm_ext : op2;

  wire [31:0] branch_target = pc + {{3{branch_offset[26]}}, branch_offset, 2'b00};

  alu u_alu (
    .a      (op1),
    .b      (alu_b),
    .alu_op (ctrl[`C_ALU_OP]),
    .result (alu_result)
  );

  flags u_flags (
    .clk      (clk),
    .rst_n    (rst_n),
    .write_en (ctrl[`C_FLAGS_WRITE]),
    .a        (op1),
    .b        (alu_b),
    .flag_e   (flag_e),
    .flag_gt  (flag_gt)
  );

  branch_unit u_branch_unit (
    .jump          (ctrl[`C_JUMP]),
    .branch        (ctrl[`C_BRANCH]),
    .branch_gt     (ctrl[`C_BRANCH_GT]),
    .is_ret        (ctrl[`C_IS_RET]),
    .flag_e        (flag_e),
    .flag_gt       (flag_gt),
    .branch_target (branch_target),
    .ret_addr      (op1),
    .branch_taken  (branch_taken),
    .branch_pc     (branch_pc)
  );

endmodule
