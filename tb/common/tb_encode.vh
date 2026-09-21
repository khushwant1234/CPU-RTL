//=============================================================================
// tb_encode.vh
// Instruction encoders for testbenches. Include inside a testbench module
// (after defines.vh is included). Bit layout matches decoder.v:
//   [31:27] opcode  [26] I  [25:22] rd  [21:18] rs1  [17:14] rs2
//   [17:16] modifier (I=1)  [15:0] imm16 (I=1)  [26:0] branch offset
//=============================================================================

// register form:  op rd, rs1, rs2
function [31:0] enc_r;
  input [4:0] op;
  input [3:0] rd, rs1, rs2;
  enc_r = {op, 1'b0, rd, rs1, rs2, 14'b0};
endfunction

// immediate form: op rd, rs1, imm   (mod: 00 default, 01 'u', 10 'h')
function [31:0] enc_i;
  input [4:0]  op;
  input [3:0]  rd, rs1;
  input [15:0] imm;
  input [1:0]  mod;
  enc_i = {op, 1'b1, rd, rs1, mod, imm};
endfunction

// branch form: op offset   (offset counted in instructions, not bytes)
function [31:0] enc_b;
  input [4:0]  op;
  input [26:0] offset;
  enc_b = {op, offset};
endfunction
