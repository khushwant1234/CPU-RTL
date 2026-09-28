`include "defines.vh"

module alu (
  input  wire [31:0] a,
  input  wire [31:0] b,
  input  wire [3:0]  alu_op,
  output reg  [31:0] result
);

  wire signed [31:0] a_s = a;
  wire signed [31:0] b_s = b;

  wire signed [31:0] quot    = a_s / b_s;
  wire signed [31:0] rem     = a_s % b_s;
  wire signed [31:0] asr_res = a_s >>> b[4:0];
  wire               b_zero  = (b == 32'b0);

  always @(*) begin
    case (alu_op)
      `ALU_ADD: result = a + b;
      `ALU_SUB: result = a - b;
      `ALU_CMP: result = a - b;
      `ALU_MUL: result = a * b;
      `ALU_DIV: result = b_zero ? 32'b0 : quot;
      `ALU_MOD: result = b_zero ? 32'b0 : rem;
      `ALU_LSL: result = a << b[4:0];
      `ALU_LSR: result = a >> b[4:0];
      `ALU_ASR: result = asr_res;
      `ALU_OR:  result = a | b;
      `ALU_AND: result = a & b;
      `ALU_NOT: result = ~b;
      `ALU_MOV: result = b;
      default:  result = 32'b0;
    endcase
  end

endmodule
