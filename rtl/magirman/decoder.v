//=============================================================================
// decoder.v
// Combinational instruction decoder. Produces normalized "effective"
// rs1_addr/rs2_addr/rd_addr for every instruction, including the special
// cases:
//   - st  : the rd field is a SOURCE register (value being stored), not a
//           write destination. We emit it as rs2_addr with rs2_valid=1,
//           and reg_write=0, so hazard_unit/forwarding_unit never need
//           instruction-specific logic -- they only ever look at
//           rs1_addr/rs2_addr/rs1_valid/rs2_valid/rd_addr/reg_write.
//   - ret : implicitly reads ra (r15) with no explicit operand field. We
//           emit rs1_addr=REG_RA, rs1_valid=1 so the hazard/forwarding
//           unit picks up a RAW dependency on a preceding write to r15.
//   - call: implicitly writes ra (r15). We emit rd_addr=REG_RA,
//           reg_write=1 even though the branch format has no rd field.
//           The actual PC+4 value is selected in writeback via is_call.
//
// ctrl is the CTRL_W-bit control bundle, bit positions in defines.vh.
//=============================================================================
`include "defines.vh"

module decoder (
  input  wire [31:0]        instr,

  output reg  [3:0]         rd_addr,
  output reg  [3:0]         rs1_addr,
  output reg  [3:0]         rs2_addr,
  output reg  [31:0]        imm_ext,        // sign/zero/upper-extended per modifier
  output wire [26:0]        branch_offset,  // raw offset field, branch format
  output reg  [`CTRL_W-1:0] ctrl
);

  // -------------------------------------------------------------------
  // Raw field extraction
  // -------------------------------------------------------------------
  wire [4:0]  opcode    = instr[31:27];
  wire        i_bit     = instr[26];
  wire [3:0]  rd_field  = instr[25:22];
  wire [3:0]  rs1_field = instr[21:18];
  wire [3:0]  rs2_field = instr[17:14];
  wire [1:0]  modifier  = instr[17:16];
  wire [15:0] imm16     = instr[15:0];

  assign branch_offset = instr[26:0];

  // -------------------------------------------------------------------
  // ALU op lookup for the 3-address arithmetic/logical group
  // -------------------------------------------------------------------
  function [3:0] alu_op_for;
    input [4:0] op;
    begin
      case (op)
        `OP_ADD: alu_op_for = `ALU_ADD;
        `OP_SUB: alu_op_for = `ALU_SUB;
        `OP_MUL: alu_op_for = `ALU_MUL;
        `OP_DIV: alu_op_for = `ALU_DIV;
        `OP_MOD: alu_op_for = `ALU_MOD;
        `OP_AND: alu_op_for = `ALU_AND;
        `OP_OR:  alu_op_for = `ALU_OR;
        `OP_LSL: alu_op_for = `ALU_LSL;
        `OP_LSR: alu_op_for = `ALU_LSR;
        `OP_ASR: alu_op_for = `ALU_ASR;
        default: alu_op_for = `ALU_NOP;
      endcase
    end
  endfunction

  // -------------------------------------------------------------------
  // Immediate extension per modifier bits
  //   00 (default) : sign-extend 16-bit 2's complement
  //   01 ('u')     : zero-extend, unsigned
  //   10 ('h')     : load into upper 16 bits, lower 16 = 0
  // -------------------------------------------------------------------
  always @(*) begin
    case (modifier)
      2'b00:   imm_ext = {{16{imm16[15]}}, imm16};
      2'b01:   imm_ext = {16'b0, imm16};
      2'b10:   imm_ext = {imm16, 16'b0};
      default: imm_ext = 32'b0;
    endcase
  end

  // -------------------------------------------------------------------
  // Main decode
  // -------------------------------------------------------------------
  always @(*) begin
    // Safe defaults == true bubble (all ctrl fields inactive, ALU_NOP)
    rd_addr  = 4'b0;
    rs1_addr = 4'b0;
    rs2_addr = 4'b0;
    ctrl     = `CTRL_BUBBLE;

    case (opcode)

      // ---- 3-address arithmetic/logical (register or immediate 2nd src) --
      `OP_ADD, `OP_SUB, `OP_MUL, `OP_DIV, `OP_MOD, `OP_AND, `OP_OR,
      `OP_LSL, `OP_LSR, `OP_ASR: begin
        rd_addr                = rd_field;
        rs1_addr               = rs1_field;
        rs2_addr               = rs2_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;   // rs2 field only meaningful if I=0
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_ALU_OP]        = alu_op_for(opcode);
      end

      // ---- cmp: 2-address, no destination write, sets flags -------------
      `OP_CMP: begin
        rs1_addr               = rs1_field;
        rs2_addr               = rs2_field;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_FLAGS_WRITE]   = 1'b1;
        ctrl[`C_ALU_OP]        = `ALU_CMP;
      end

      // ---- not/mov: 2-address, source in rs2 field, rs1 field unused ----
      `OP_NOT, `OP_MOV: begin
        rd_addr                = rd_field;
        rs2_addr               = rs2_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_ALU_OP]        = (opcode == `OP_NOT) ? `ALU_NOT : `ALU_MOV;
      end

      // ---- ld: rd <- MEM[rs1 + imm] --------------------------------------
      `OP_LD: begin
        rd_addr                = rd_field;
        rs1_addr               = rs1_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_MEM_READ]      = 1'b1;
        ctrl[`C_MEM_TO_REG]    = 1'b1;
        ctrl[`C_ALU_SRC_IMM]   = 1'b1;   // address = rs1 + imm, always
        ctrl[`C_ALU_OP]        = `ALU_ADD;
      end

      // ---- st: MEM[rs1 + imm] <- rd (as source!) -------------------------
      // rd_field here is the value being STORED, not a write destination.
      // Normalized onto rs2 so hazard_unit treats it like any other source.
      `OP_ST: begin
        rs1_addr               = rs1_field;   // base register
        rs2_addr               = rd_field;    // source register being stored
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = 1'b1;
        ctrl[`C_MEM_WRITE]     = 1'b1;        // st never writes a register
        ctrl[`C_ALU_SRC_IMM]   = 1'b1;        // address = rs1 + imm
        ctrl[`C_ALU_OP]        = `ALU_ADD;
      end

      // ---- b / call: unconditional branch-format ------------------------
      `OP_B, `OP_CALL: begin
        ctrl[`C_JUMP]          = 1'b1;
        if (opcode == `OP_CALL) begin
          rd_addr              = `REG_RA;     // implicit write, no field in encoding
          ctrl[`C_IS_CALL]     = 1'b1;
          ctrl[`C_REG_WRITE]   = 1'b1;
        end
      end

      // ---- beq / bgt: conditional branch-format, reads flags not GPRs ---
      `OP_BEQ, `OP_BGT: begin
        ctrl[`C_BRANCH]        = 1'b1;
        ctrl[`C_BRANCH_GT]     = (opcode == `OP_BGT);
      end

      // ---- ret: implicit read of ra (r15), no operand field --------------
      `OP_RET: begin
        rs1_addr               = `REG_RA;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_IS_RET]        = 1'b1;
      end

      // ---- nop and unrecognized opcodes: defaults above (true bubble) ----
      default: begin
      end
    endcase
  end

endmodule
