//=============================================================================
// execute_stage.sv
// EX stage: ALU + flags + branch resolution.
//
// op1/op2 come in AFTER the forwarding muxes (done in the top level with
// forwarding_unit), so this stage never looks at pipeline register contents
// other than the ID/EX values it is given.
//
// Branch target (SimpleRisc): offset is a 27-bit signed count of
// instructions, target = pc + (sign_ext(offset) << 2).
//=============================================================================
module execute_stage
  import simpleriscprocessor_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [31:0] pc,            // pc of the instruction in EX
  input  logic [31:0] op1,           // rs1 value (forwarded)
  input  logic [31:0] op2,           // rs2 value (forwarded)
  input  logic [31:0] imm_ext,
  input  logic [26:0] branch_offset,
  input  ctrl_t       ctrl,

  output logic [31:0] alu_result,
  output logic        flag_e,
  output logic        flag_gt,
  output logic        branch_taken,
  output logic [31:0] branch_pc
);

  logic [31:0] alu_b;
  logic [31:0] branch_target;

  // I bit: second operand is the immediate
  assign alu_b = ctrl.alu_src_imm ? imm_ext : op2;

  assign branch_target = pc + {{3{branch_offset[26]}}, branch_offset, 2'b00};

  alu u_alu (
    .a      (op1),
    .b      (alu_b),
    .alu_op (ctrl.alu_op),
    .result (alu_result)
  );

  flags u_flags (
    .clk      (clk),
    .rst_n    (rst_n),
    .write_en (ctrl.flags_write_en),
    .a        (op1),
    .b        (alu_b),
    .flag_e   (flag_e),
    .flag_gt  (flag_gt)
  );

  branch_unit u_branch_unit (
    .jump          (ctrl.jump),
    .branch        (ctrl.branch),
    .branch_gt     (ctrl.branch_gt),
    .is_ret        (ctrl.is_ret),
    .flag_e        (flag_e),
    .flag_gt       (flag_gt),
    .branch_target (branch_target),
    .ret_addr      (op1),
    .branch_taken  (branch_taken),
    .branch_pc     (branch_pc)
  );

endmodule : execute_stage
