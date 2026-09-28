`include "defines.vh"

module decoder (
  input  wire [31:0]        instr,

  output reg  [3:0]         rd_addr,
  output reg  [3:0]         rs1_addr,
  output reg  [3:0]         rs2_addr,
  output reg  [31:0]        imm_ext,
  output wire [26:0]        branch_offset,
  output reg  [`CTRL_W-1:0] ctrl
);

  wire [4:0]  opcode    = instr[31:27];
  wire        i_bit     = instr[26];
  wire [3:0]  rd_field  = instr[25:22];
  wire [3:0]  rs1_field = instr[21:18];
  wire [3:0]  rs2_field = instr[17:14];
  wire [1:0]  modifier  = instr[17:16];
  wire [15:0] imm16     = instr[15:0];

  assign branch_offset = instr[26:0];

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

  always @(*) begin
    case (modifier)
      2'b00:   imm_ext = {{16{imm16[15]}}, imm16};
      2'b01:   imm_ext = {16'b0, imm16};
      2'b10:   imm_ext = {imm16, 16'b0};
      default: imm_ext = 32'b0;
    endcase
  end

  always @(*) begin
    rd_addr  = 4'b0;
    rs1_addr = 4'b0;
    rs2_addr = 4'b0;
    ctrl     = `CTRL_BUBBLE;

    case (opcode)

      `OP_ADD, `OP_SUB, `OP_MUL, `OP_DIV, `OP_MOD, `OP_AND, `OP_OR,
      `OP_LSL, `OP_LSR, `OP_ASR: begin
        rd_addr                = rd_field;
        rs1_addr               = rs1_field;
        rs2_addr               = rs2_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_ALU_OP]        = alu_op_for(opcode);
      end

      `OP_CMP: begin
        rs1_addr               = rs1_field;
        rs2_addr               = rs2_field;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_FLAGS_WRITE]   = 1'b1;
        ctrl[`C_ALU_OP]        = `ALU_CMP;
      end

      `OP_NOT, `OP_MOV: begin
        rd_addr                = rd_field;
        rs2_addr               = rs2_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS2_VALID]     = ~i_bit;
        ctrl[`C_ALU_SRC_IMM]   = i_bit;
        ctrl[`C_ALU_OP]        = (opcode == `OP_NOT) ? `ALU_NOT : `ALU_MOV;
      end

      `OP_LD: begin
        rd_addr                = rd_field;
        rs1_addr               = rs1_field;
        ctrl[`C_REG_WRITE]     = 1'b1;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_MEM_READ]      = 1'b1;
        ctrl[`C_MEM_TO_REG]    = 1'b1;
        ctrl[`C_ALU_SRC_IMM]   = 1'b1;
        ctrl[`C_ALU_OP]        = `ALU_ADD;
      end

      `OP_ST: begin
        rs1_addr               = rs1_field;
        rs2_addr               = rd_field;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_RS2_VALID]     = 1'b1;
        ctrl[`C_MEM_WRITE]     = 1'b1;
        ctrl[`C_ALU_SRC_IMM]   = 1'b1;
        ctrl[`C_ALU_OP]        = `ALU_ADD;
      end

      `OP_B, `OP_CALL: begin
        ctrl[`C_JUMP]          = 1'b1;
        if (opcode == `OP_CALL) begin
          rd_addr              = `REG_RA;
          ctrl[`C_IS_CALL]     = 1'b1;
          ctrl[`C_REG_WRITE]   = 1'b1;
        end
      end

      `OP_BEQ, `OP_BGT: begin
        ctrl[`C_BRANCH]        = 1'b1;
        ctrl[`C_BRANCH_GT]     = (opcode == `OP_BGT);
      end

      `OP_RET: begin
        rs1_addr               = `REG_RA;
        ctrl[`C_RS1_VALID]     = 1'b1;
        ctrl[`C_IS_RET]        = 1'b1;
      end

      default: begin
      end
    endcase
  end

endmodule
