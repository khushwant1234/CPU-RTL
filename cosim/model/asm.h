#pragma once
#include <cstdio>
#include <string>
#include "defines.h"

inline uint32_t enc_r(uint32_t op, uint32_t rd, uint32_t rs1, uint32_t rs2) {
    return op << 27 | rd << 22 | rs1 << 18 | rs2 << 14;
}

inline uint32_t enc_i(uint32_t op, uint32_t rd, uint32_t rs1, uint32_t imm, uint32_t mod = 0) {
    return op << 27 | 1u << 26 | rd << 22 | rs1 << 18 | mod << 16 | (imm & 0xFFFF);
}

inline uint32_t enc_b(uint32_t op, int32_t offset) {
    return op << 27 | ((uint32_t)offset & 0x7FFFFFF);
}

inline const char* op_name(uint32_t op) {
    static const char* names[] = {"add", "sub", "mul", "div", "mod", "cmp", "and", "or",
                                  "not", "mov", "lsl", "lsr", "asr", "nop", "ld", "st",
                                  "beq", "bgt", "b", "call", "ret"};
    return op <= OP_RET ? names[op] : "???";
}

inline std::string disasm(uint32_t ins, uint32_t pc) {
    uint32_t op = ins >> 27;
    bool imm_form = bit(ins, 26);
    uint32_t rd = (ins >> 22) & 0xF;
    uint32_t rs1 = (ins >> 18) & 0xF;
    uint32_t rs2 = (ins >> 14) & 0xF;
    uint32_t mod = (ins >> 16) & 3;
    uint32_t imm = ins & 0xFFFF;

    std::string name = op_name(op);
    std::string src2 = "r" + std::to_string(rs2);
    if (imm_form) {
        char tmp[16];
        if (mod == 0)
            snprintf(tmp, sizeof tmp, "%d", (int16_t)imm);
        else
            snprintf(tmp, sizeof tmp, "0x%x", imm);
        src2 = tmp;
        if (mod == 1) name += "u";
        if (mod == 2) name += "h";
    }

    char buf[80];
    switch (op) {
    case OP_CMP:
        snprintf(buf, sizeof buf, "%s r%u, %s", name.c_str(), rs1, src2.c_str());
        break;
    case OP_NOT:
    case OP_MOV:
        snprintf(buf, sizeof buf, "%s r%u, %s", name.c_str(), rd, src2.c_str());
        break;
    case OP_LD:
    case OP_ST:
        snprintf(buf, sizeof buf, "%s r%u, %d[r%u]", op_name(op), rd, (int16_t)imm, rs1);
        break;
    case OP_BEQ:
    case OP_BGT:
    case OP_B:
    case OP_CALL: {
        uint32_t target = pc + (sign_extend27(ins) << 2);
        if (op == OP_B && target == pc)
            snprintf(buf, sizeof buf, "b .");
        else
            snprintf(buf, sizeof buf, "%s 0x%x", op_name(op), target);
        break;
    }
    case OP_NOP:
    case OP_RET:
        snprintf(buf, sizeof buf, "%s", op_name(op));
        break;
    default:
        if (op > OP_RET)
            snprintf(buf, sizeof buf, ".word 0x%08x", ins);
        else
            snprintf(buf, sizeof buf, "%s r%u, r%u, %s", name.c_str(), rd, rs1, src2.c_str());
    }
    return buf;
}
