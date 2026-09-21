//=============================================================================
// decoder.sv
// Combinational instruction decoder. Produces normalized "effective"
// rs1_addr/rs2_addr/rd_addr for every instruction, INCLUDING the two
// special cases flagged in the design doc (Sec 5.3):
//   - st  : the rd field is a SOURCE register (value being stored), not a
//           write destination. We emit it as rs2_addr with rs2_valid=1,
//           and reg_write_en=0, so hazard_unit/forwarding_unit never need
//           instruction-specific logic -- they only ever look at
//           rs1_addr/rs2_addr/rs1_valid/rs2_valid/rd_addr/reg_write_en.
//   - ret : implicitly reads ra (r15) with no explicit operand field. We
//           emit rs1_addr=REG_RA, rs1_valid=1 so the hazard/forwarding
//           unit picks up a RAW dependency on a preceding write to r15
//           (e.g. from call) automatically.
//   - call: implicitly writes ra (r15). We emit rd_addr=REG_RA,
//           reg_write_en=1 even though the branch-format encoding has no
//           rd field. The actual PC+4 value is supplied by branch_unit
//           and selected at the writeback_mux via ctrl.is_call.
//=============================================================================
module decoder
  import simpleriscprocessor_pkg::*;
(
  input  logic [31:0] instr,

  output logic [3:0]  rd_addr,
  output logic [3:0]  rs1_addr,
  output logic [3:0]  rs2_addr,
  output logic [31:0] imm_ext,        // sign/zero/upper-extended per modifier
  output logic [26:0] branch_offset,  // raw offset field, branch format
  output ctrl_t        ctrl
);

  // -------------------------------------------------------------------
  // Raw field extraction (see design doc Sec 1.1 for bit layout)
  // -------------------------------------------------------------------
  opcode_e            opcode;
  logic                i_bit;
  logic        [3:0]  rd_field, rs1_field, rs2_field;
  logic        [17:0] imm_field;
  logic        [1:0]  modifier;
  logic        [15:0] imm16;

  assign opcode        = opcode_e'(instr[31:27]);
  assign i_bit          = instr[26];
  assign rd_field       = instr[25:22];
  assign rs1_field      = instr[21:18];
  assign rs2_field      = instr[17:14];
  assign imm_field      = instr[17:0];
  assign modifier       = imm_field[17:16];
  assign imm16          = imm_field[15:0];
  assign branch_offset  = instr[26:0];

  // -------------------------------------------------------------------
  // Immediate extension per modifier bits (design doc Sec 3.13 semantics)
  //   00 (default) : sign-extend 16-bit 2's complement
  //   01 ('u')     : zero-extend, unsigned
  //   10 ('h')     : load into upper 16 bits, lower 16 = 0
  // -------------------------------------------------------------------
  always_comb begin
    unique case (modifier)
      2'b00:   imm_ext = {{16{imm16[15]}}, imm16};
      2'b01:   imm_ext = {16'b0, imm16};
      2'b10:   imm_ext = {imm16, 16'b0};
      default: imm_ext = 32'b0;
    endcase
  end

  // -------------------------------------------------------------------
  // Main decode
  // -------------------------------------------------------------------
  always_comb begin
    // Safe defaults == true bubble (all ctrl fields inactive)
    rd_addr           = 4'b0;
    rs1_addr           = 4'b0;
    rs2_addr           = 4'b0;
    ctrl               = '0;
    ctrl.alu_op        = ALU_NOP;

    unique case (opcode)

      // ---- 3-address arithmetic/logical (register or immediate 2nd src) --
      OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_AND, OP_OR,
      OP_LSL, OP_LSR, OP_ASR: begin
        rd_addr           = rd_field;
        rs1_addr           = rs1_field;
        rs2_addr           = rs2_field;
        ctrl.reg_write_en  = 1'b1;
        ctrl.rs1_valid     = 1'b1;
        ctrl.rs2_valid     = ~i_bit;   // rs2 field only meaningful if I=0
        ctrl.alu_src_imm   = i_bit;
        ctrl.alu_op        = alu_op_for(opcode);
      end

      // ---- cmp: 2-address, no destination write, sets flags -------------
      OP_CMP: begin
        rs1_addr           = rs1_field;
        rs2_addr           = rs2_field;
        ctrl.rs1_valid     = 1'b1;
        ctrl.rs2_valid     = ~i_bit;
        ctrl.alu_src_imm   = i_bit;
        ctrl.flags_write_en = 1'b1;
        ctrl.alu_op        = ALU_CMP;
      end

      // ---- not/mov: 2-address, source in rs2 field, rs1 field unused ----
      OP_NOT, OP_MOV: begin
        rd_addr           = rd_field;
        rs2_addr           = rs2_field;
        ctrl.reg_write_en  = 1'b1;
        ctrl.rs1_valid     = 1'b0;
        ctrl.rs2_valid     = ~i_bit;
        ctrl.alu_src_imm   = i_bit;
        if (opcode == OP_NOT) ctrl.alu_op = ALU_NOT;
        else                  ctrl.alu_op = ALU_MOV;
      end

      // ---- ld: rd <- MEM[rs1 + imm] --------------------------------------
      OP_LD: begin
        rd_addr            = rd_field;
        rs1_addr           = rs1_field;
        ctrl.reg_write_en  = 1'b1;
        ctrl.rs1_valid     = 1'b1;
        ctrl.mem_read_en   = 1'b1;
        ctrl.mem_to_reg    = 1'b1;
        ctrl.alu_src_imm   = 1'b1;   // address = rs1 + imm, always
        ctrl.alu_op        = ALU_ADD;
      end

      // ---- st: MEM[rs1 + imm] <- rd(as source!) --------------------------
      // NOTE: rd_field here is the value being STORED, not a write dest.
      // Normalized as rs2_addr/rs2_valid so hazard_unit treats it exactly
      // like any other source-register read -- see file header.
      OP_ST: begin
        rs1_addr           = rs1_field;   // base register
        rs2_addr           = rd_field;    // source register being stored
        ctrl.rs1_valid     = 1'b1;
        ctrl.rs2_valid     = 1'b1;
        ctrl.reg_write_en  = 1'b0;        // st never writes a register
        ctrl.mem_write_en  = 1'b1;
        ctrl.alu_src_imm   = 1'b1;        // address = rs1 + imm
        ctrl.alu_op        = ALU_ADD;
      end

      // ---- b / call: unconditional branch-format ------------------------
      OP_B, OP_CALL: begin
        ctrl.jump          = 1'b1;
        ctrl.is_call       = (opcode == OP_CALL);
        if (opcode == OP_CALL) begin
          rd_addr           = REG_RA;     // implicit write, no field in encoding
          ctrl.reg_write_en = 1'b1;
        end
      end

      // ---- beq / bgt: conditional branch-format, reads flags not GPRs ---
      OP_BEQ, OP_BGT: begin
        ctrl.branch        = 1'b1;
        ctrl.branch_gt     = (opcode == OP_BGT);
      end

      // ---- ret: implicit read of ra (r15), no operand field --------------
      OP_RET: begin
        rs1_addr           = REG_RA;
        ctrl.rs1_valid     = 1'b1;
        ctrl.is_ret        = 1'b1;
      end

      // ---- nop / unrecognized: inert, defaults above already cover it ---
      OP_NOP: begin
        // all defaults already correct (true bubble)
      end

      default: begin
        // Unrecognized opcode -- treat as nop for safety rather than X
        // propagation; consider an illegal-instruction trap here if your
        // project scope grows to include exception handling.
        ctrl = '0;
        ctrl.alu_op = ALU_NOP;
      end
    endcase
  end

  // -------------------------------------------------------------------
  // ALU op lookup for the 3-address arithmetic/logical group
  // -------------------------------------------------------------------
  function automatic alu_op_e alu_op_for(input opcode_e op);
    unique case (op)
      OP_ADD:  alu_op_for = ALU_ADD;
      OP_SUB:  alu_op_for = ALU_SUB;
      OP_MUL:  alu_op_for = ALU_MUL;
      OP_DIV:  alu_op_for = ALU_DIV;
      OP_MOD:  alu_op_for = ALU_MOD;
      OP_AND:  alu_op_for = ALU_AND;
      OP_OR:   alu_op_for = ALU_OR;
      OP_LSL:  alu_op_for = ALU_LSL;
      OP_LSR:  alu_op_for = ALU_LSR;
      OP_ASR:  alu_op_for = ALU_ASR;
      default: alu_op_for = ALU_NOP;
    endcase
  endfunction

endmodule : decoder
