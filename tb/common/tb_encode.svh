//=============================================================================
// tb_encode.svh
// Instruction encoders for testbenches. Include inside a module that
// imports simpleriscprocessor_pkg. Bit layout matches decoder.sv:
//   [31:27] opcode  [26] I  [25:22] rd  [21:18] rs1  [17:14] rs2
//   [17:16] modifier (I=1)  [15:0] imm16 (I=1)  [26:0] branch offset
//=============================================================================
`ifndef TB_ENCODE_SVH
`define TB_ENCODE_SVH

// register form:  op rd, rs1, rs2
function automatic logic [31:0] enc_r(opcode_e op, logic [3:0] rd,
                                      logic [3:0] rs1, logic [3:0] rs2);
  return {op, 1'b0, rd, rs1, rs2, 14'b0};
endfunction

// immediate form: op rd, rs1, imm   (mod: 00 default, 01 'u', 10 'h')
function automatic logic [31:0] enc_i(opcode_e op, logic [3:0] rd,
                                      logic [3:0] rs1, logic [15:0] imm,
                                      logic [1:0] mod = 2'b00);
  return {op, 1'b1, rd, rs1, mod, imm};
endfunction

// branch form: op offset   (offset counted in instructions, not bytes)
function automatic logic [31:0] enc_b(opcode_e op, logic [26:0] offset);
  return {op, offset};
endfunction

`endif
