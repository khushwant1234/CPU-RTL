//=============================================================================
// alu.sv
// Combinational ALU for the EX stage. Operation is selected by alu_op from
// the decoder (simpleriscprocessor_pkg::alu_op_e) instead of the separate
// isAdd/isSub/... one-hot inputs used in the first version.
//
//   a = op1 (rs1, forwarded)
//   b = op2 (rs2, forwarded) or the immediate, muxed in execute_stage
//
// SimpleRisc integers are 32-bit 2's complement, so div/mod/asr are signed.
// Divide or mod by zero returns 0 so simulation never produces X.
// not/mov only use b (the rs2 / immediate operand), same as the ISA.
//=============================================================================
module alu
  import simpleriscprocessor_pkg::*;
(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  alu_op_e     alu_op,
  output logic [31:0] result
);

  logic signed [31:0] a_s, b_s;
  assign a_s = a;
  assign b_s = b;

  always_comb begin
    case (alu_op)
      ALU_ADD: result = a + b;
      ALU_SUB: result = a - b;
      ALU_CMP: result = a - b;                  // result unused, flags do the work
      ALU_MUL: result = a * b;                  // low 32 bits
      ALU_DIV: result = (b == 32'b0) ? 32'b0 : 32'(a_s / b_s);
      ALU_MOD: result = (b == 32'b0) ? 32'b0 : 32'(a_s % b_s);
      ALU_LSL: result = a << b[4:0];
      ALU_LSR: result = a >> b[4:0];
      ALU_ASR: result = 32'(a_s >>> b[4:0]);
      ALU_OR:  result = a | b;
      ALU_AND: result = a & b;
      ALU_NOT: result = ~b;
      ALU_MOV: result = b;
      default: result = 32'b0;                  // ALU_NOP and bubbles
    endcase
  end

endmodule : alu
