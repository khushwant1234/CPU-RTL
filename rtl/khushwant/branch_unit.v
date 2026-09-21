//=============================================================================
// branch_unit.v
// Decides if the instruction in EX redirects the PC and where to.
//
//   b / call : always taken, target = branch_target
//   beq      : taken if flag E
//   bgt      : taken if flag GT
//   ret      : always taken, target = ra (op1, already forwarded)
//
// Branches are resolved in EX, so a taken branch flushes the two younger
// instructions sitting in IF/ID and ID/EX (done by hazard_unit).
//=============================================================================
module branch_unit (
  input  wire        jump,          // b, call
  input  wire        branch,        // beq, bgt
  input  wire        branch_gt,     // 1 = bgt, 0 = beq
  input  wire        is_ret,
  input  wire        flag_e,
  input  wire        flag_gt,
  input  wire [31:0] branch_target, // pc + (offset << 2)
  input  wire [31:0] ret_addr,      // op1 = value of r15
  output wire        branch_taken,
  output wire [31:0] branch_pc
);

  wire cond_ok = branch_gt ? flag_gt : flag_e;

  assign branch_taken = jump | is_ret | (branch & cond_ok);
  assign branch_pc    = is_ret ? ret_addr : branch_target;

endmodule
