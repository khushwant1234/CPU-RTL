#pragma once
#include "defines.h"

inline uint32_t alu(uint32_t a, uint32_t b, uint32_t op) {
    int64_t sa = (int32_t)a;
    int64_t sb = (int32_t)b;

    switch (op) {
    case ALU_ADD: return a + b;
    case ALU_SUB:
    case ALU_CMP: return a - b;
    case ALU_MUL: return a * b;
    case ALU_DIV: return b == 0 ? 0 : (uint32_t)(sa / sb);
    case ALU_MOD: return b == 0 ? 0 : (uint32_t)(sa % sb);
    case ALU_AND: return a & b;
    case ALU_OR:  return a | b;
    case ALU_NOT: return ~b;
    case ALU_MOV: return b;
    case ALU_LSL: return a << (b & 31);
    case ALU_LSR: return a >> (b & 31);
    case ALU_ASR: return (uint32_t)((int32_t)a >> (b & 31));
    default:      return 0;
    }
}
