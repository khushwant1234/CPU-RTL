#pragma once
#include "defines.h"

struct Decoded {
    uint32_t rd = 0;
    uint32_t rs1 = 0;
    uint32_t rs2 = 0;
    uint32_t imm = 0;
    uint32_t offset = 0;
    uint32_t ctrl = CTRL_BUBBLE;
};

inline uint32_t alu_op_for(uint32_t opcode) {
    switch (opcode) {
    case OP_ADD: return ALU_ADD;
    case OP_SUB: return ALU_SUB;
    case OP_MUL: return ALU_MUL;
    case OP_DIV: return ALU_DIV;
    case OP_MOD: return ALU_MOD;
    case OP_AND: return ALU_AND;
    case OP_OR:  return ALU_OR;
    case OP_LSL: return ALU_LSL;
    case OP_LSR: return ALU_LSR;
    case OP_ASR: return ALU_ASR;
    default:     return ALU_NOP;
    }
}

inline uint32_t extend_imm(uint32_t imm16, uint32_t modifier) {
    switch (modifier) {
    case 0:  return (uint32_t)(int32_t)(int16_t)imm16;
    case 1:  return imm16;
    case 2:  return imm16 << 16;
    default: return 0;
    }
}

inline Decoded decode(uint32_t instr) {
    uint32_t opcode = instr >> 27;
    bool imm_form = bit(instr, 26);
    uint32_t rd_field = (instr >> 22) & 0xF;
    uint32_t rs1_field = (instr >> 18) & 0xF;
    uint32_t rs2_field = (instr >> 14) & 0xF;

    Decoded d;
    d.imm = extend_imm(instr & 0xFFFF, (instr >> 16) & 3);
    d.offset = instr & 0x7FFFFFF;

    auto set = [&](int b, bool on = true) {
        if (on) d.ctrl |= 1u << b;
    };
    auto set_alu_op = [&](uint32_t op) {
        d.ctrl = (d.ctrl & ~(0xFu << C_ALU_OP)) | (op << C_ALU_OP);
    };

    switch (opcode) {
    case OP_ADD: case OP_SUB: case OP_MUL: case OP_DIV: case OP_MOD:
    case OP_AND: case OP_OR:  case OP_LSL: case OP_LSR: case OP_ASR:
        d.rd = rd_field;
        d.rs1 = rs1_field;
        d.rs2 = rs2_field;
        set(C_REG_WRITE);
        set(C_RS1_VALID);
        set(C_RS2_VALID, !imm_form);
        set(C_ALU_SRC_IMM, imm_form);
        set_alu_op(alu_op_for(opcode));
        break;

    case OP_CMP:
        d.rs1 = rs1_field;
        d.rs2 = rs2_field;
        set(C_RS1_VALID);
        set(C_RS2_VALID, !imm_form);
        set(C_ALU_SRC_IMM, imm_form);
        set(C_FLAGS_WRITE);
        set_alu_op(ALU_CMP);
        break;

    case OP_NOT:
    case OP_MOV:
        d.rd = rd_field;
        d.rs2 = rs2_field;
        set(C_REG_WRITE);
        set(C_RS2_VALID, !imm_form);
        set(C_ALU_SRC_IMM, imm_form);
        set_alu_op(opcode == OP_NOT ? ALU_NOT : ALU_MOV);
        break;

    case OP_LD:
        d.rd = rd_field;
        d.rs1 = rs1_field;
        set(C_REG_WRITE);
        set(C_RS1_VALID);
        set(C_MEM_READ);
        set(C_MEM_TO_REG);
        set(C_ALU_SRC_IMM);
        set_alu_op(ALU_ADD);
        break;

    case OP_ST:
        d.rs1 = rs1_field;
        d.rs2 = rd_field;
        set(C_RS1_VALID);
        set(C_RS2_VALID);
        set(C_MEM_WRITE);
        set(C_ALU_SRC_IMM);
        set_alu_op(ALU_ADD);
        break;

    case OP_B:
    case OP_CALL:
        set(C_JUMP);
        if (opcode == OP_CALL) {
            d.rd = REG_RA;
            set(C_IS_CALL);
            set(C_REG_WRITE);
        }
        break;

    case OP_BEQ:
    case OP_BGT:
        set(C_BRANCH);
        set(C_BRANCH_GT, opcode == OP_BGT);
        break;

    case OP_RET:
        d.rs1 = REG_RA;
        set(C_RS1_VALID);
        set(C_IS_RET);
        break;

    default:
        break;
    }
    return d;
}
