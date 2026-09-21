//=============================================================================
// defines.vh
// Shared opcode / control definitions for the SimpleRisc pipelined processor.
// Every RTL file includes this. (Plain Verilog replacement for the old
// simpleriscprocessor_pkg.sv -- same values, no SystemVerilog types.)
//
// Bit convention: instr[31:27] = opcode, instr[26] = I bit.
//=============================================================================
`ifndef DEFINES_VH
`define DEFINES_VH

// ---------------------------------------------------------------------------
// Opcodes
// ---------------------------------------------------------------------------
`define OP_ADD   5'b00000
`define OP_SUB   5'b00001
`define OP_MUL   5'b00010
`define OP_DIV   5'b00011
`define OP_MOD   5'b00100
`define OP_CMP   5'b00101
`define OP_AND   5'b00110
`define OP_OR    5'b00111
`define OP_NOT   5'b01000
`define OP_MOV   5'b01001
`define OP_LSL   5'b01010
`define OP_LSR   5'b01011
`define OP_ASR   5'b01100
`define OP_NOP   5'b01101
`define OP_LD    5'b01110
`define OP_ST    5'b01111
`define OP_BEQ   5'b10000
`define OP_BGT   5'b10001
`define OP_B     5'b10010
`define OP_CALL  5'b10011
`define OP_RET   5'b10100

// Full encoding of nop ({OP_NOP, 27'b0}). Used to reset/flush IF/ID instead
// of all-zeros, which would decode as "add r0, r0, r0".
`define NOP_INSTR 32'h6800_0000

// Stack pointer / return address registers
`define REG_SP   4'd14
`define REG_RA   4'd15

// ---------------------------------------------------------------------------
// ALU operation (decoder output, ALU input), 4 bits
// ---------------------------------------------------------------------------
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_MUL  4'd2
`define ALU_DIV  4'd3
`define ALU_MOD  4'd4
`define ALU_AND  4'd5
`define ALU_OR   4'd6
`define ALU_NOT  4'd7
`define ALU_MOV  4'd8
`define ALU_LSL  4'd9
`define ALU_LSR  4'd10
`define ALU_ASR  4'd11
`define ALU_CMP  4'd12
`define ALU_NOP  4'd13

// ---------------------------------------------------------------------------
// Control bundle: produced by the decoder in ID and carried through every
// pipeline register as one CTRL_W-bit vector. Use the bit positions below,
// e.g. ctrl[`C_REG_WRITE] or ctrl[`C_ALU_OP].
// ---------------------------------------------------------------------------
`define CTRL_W          17

`define C_REG_WRITE     0    // writes rd_addr at WB
`define C_MEM_READ      1    // ld
`define C_MEM_WRITE     2    // st
`define C_BRANCH        3    // beq/bgt (conditional)
`define C_BRANCH_GT     4    // 1 = bgt (test GT), 0 = beq (test E)
`define C_JUMP          5    // b/call (unconditional)
`define C_IS_CALL       6    // writes ra = PC+4
`define C_IS_RET        7    // reads ra, jumps to it
`define C_ALU_SRC_IMM   8    // I bit: 2nd ALU operand is imm_ext
`define C_MEM_TO_REG    9    // WB mux: 1 = load data, 0 = alu result
`define C_FLAGS_WRITE   10   // cmp
`define C_RS1_VALID     11   // instruction really reads rs1_addr
`define C_RS2_VALID     12   // instruction really reads rs2_addr
`define C_ALU_OP        16:13

// A true bubble: no writes, no branches, alu_op = ALU_NOP.
// (all-zero would give alu_op = ALU_ADD, so don't use 0 for flushes)
`define CTRL_BUBBLE     {`ALU_NOP, 13'b0}

// ---------------------------------------------------------------------------
// Forwarding mux select (forwarding_unit -> EX operand muxes)
// ---------------------------------------------------------------------------
`define FWD_NONE        2'b00   // value read from the reg file in ID
`define FWD_EX_MEM      2'b01   // result of the instruction in MEM
`define FWD_MEM_WB      2'b10   // result of the instruction in WB

`endif
