//=============================================================================
// simpleriscprocessor_pkg.sv
// Shared opcode/control definitions for the SimpleRisc pipelined processor.
// Both Person A (fetch/decode) and Person B (execute/mem/wb) import this.
// Bit convention: instr[31:27]=opcode, instr[26]=I bit, matches design doc
// Table 1.1 (op bits 28-32 in 1-indexed textbook notation == instr[31:27]).
//=============================================================================
package simpleriscprocessor_pkg;

  // ---------------------------------------------------------------------
  // Opcodes (design doc Sec 1.2)
  // ---------------------------------------------------------------------
  typedef enum logic [4:0] {
    OP_ADD  = 5'b00000,
    OP_SUB  = 5'b00001,
    OP_MUL  = 5'b00010,
    OP_DIV  = 5'b00011,
    OP_MOD  = 5'b00100,
    OP_CMP  = 5'b00101,
    OP_AND  = 5'b00110,
    OP_OR   = 5'b00111,
    OP_NOT  = 5'b01000,
    OP_MOV  = 5'b01001,
    OP_LSL  = 5'b01010,
    OP_LSR  = 5'b01011,
    OP_ASR  = 5'b01100,
    OP_NOP  = 5'b01101,
    OP_LD   = 5'b01110,
    OP_ST   = 5'b01111,
    OP_BEQ  = 5'b10000,
    OP_BGT  = 5'b10001,
    OP_B    = 5'b10010,
    OP_CALL = 5'b10011,
    OP_RET  = 5'b10100
  } opcode_e;

  // Full 32-bit encoding of nop, used to init/flush pipeline registers to a
  // safe bubble instead of all-zeros (which decodes as "add r0,r0,r0" and
  // is NOT the same as a true no-op with reg_write_en=0).
  localparam logic [31:0] NOP_INSTR = {OP_NOP, 27'b0};

  // Return-address / stack-pointer register indices
  localparam logic [3:0] REG_RA = 4'd15;
  localparam logic [3:0] REG_SP = 4'd14;

  // ---------------------------------------------------------------------
  // Internal ALU operation encoding (decoder output, ALU input)
  // ---------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_MUL, ALU_DIV, ALU_MOD, ALU_AND, ALU_OR,
    ALU_NOT, ALU_MOV, ALU_LSL, ALU_LSR, ALU_ASR, ALU_CMP, ALU_NOP
  } alu_op_e;

  // ---------------------------------------------------------------------
  // Control signal bundle produced by the decoder in ID, carried through
  // every downstream pipeline register.
  // ---------------------------------------------------------------------
  typedef struct packed {
    logic       reg_write_en;   // writes rd_addr at WB
    logic       mem_read_en;    // ld
    logic       mem_write_en;   // st
    logic       branch;         // beq/bgt (conditional)
    logic       jump;           // b/call (unconditional)
    logic       is_call;        // writes ra = PC+4
    logic       is_ret;         // reads ra, jumps to it
    logic       alu_src_imm;    // I bit: 1 = second ALU operand is imm_ext
    logic       mem_to_reg;     // WB mux: 1 = write mem data, 0 = write alu result
    logic       flags_write_en; // cmp
    logic       rs1_valid;      // this instruction actually reads rs1_addr
    logic       rs2_valid;      // this instruction actually reads rs2_addr
    alu_op_e    alu_op;
  } ctrl_t;

  // All-zero ctrl_t == a true bubble: no writes, no branches, ALU_NOP.
  // (SystemVerilog '0 assignment on a packed struct sets every field to 0,
  // and alu_op_e's 0-value is ALU_ADD by declaration order above -- flush
  // logic should explicitly force alu_op to ALU_NOP, see if_id_reg/id_ex_reg.)

endpackage : simpleriscprocessor_pkg
