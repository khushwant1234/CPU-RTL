module branch_unit (
  input  wire        jump,
  input  wire        branch,
  input  wire        branch_gt,
  input  wire        is_ret,
  input  wire        flag_e,
  input  wire        flag_gt,
  input  wire [31:0] branch_target,
  input  wire [31:0] ret_addr,
  output wire        branch_taken,
  output wire [31:0] branch_pc
);

  wire cond_ok = branch_gt ? flag_gt : flag_e;

  assign branch_taken = jump | is_ret | (branch & cond_ok);
  assign branch_pc    = is_ret ? ret_addr : branch_target;

endmodule
