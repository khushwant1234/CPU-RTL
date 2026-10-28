#pragma once
#include <cstdint>

constexpr uint32_t OP_ADD = 0, OP_SUB = 1, OP_MUL = 2, OP_DIV = 3, OP_MOD = 4, OP_CMP = 5,
                   OP_AND = 6, OP_OR = 7, OP_NOT = 8, OP_MOV = 9, OP_LSL = 10, OP_LSR = 11,
                   OP_ASR = 12, OP_NOP = 13, OP_LD = 14, OP_ST = 15, OP_BEQ = 16, OP_BGT = 17,
                   OP_B = 18, OP_CALL = 19, OP_RET = 20;

constexpr uint32_t ALU_ADD = 0, ALU_SUB = 1, ALU_MUL = 2, ALU_DIV = 3, ALU_MOD = 4, ALU_AND = 5,
                   ALU_OR = 6, ALU_NOT = 7, ALU_MOV = 8, ALU_LSL = 9, ALU_LSR = 10, ALU_ASR = 11,
                   ALU_CMP = 12, ALU_NOP = 13;

constexpr int C_REG_WRITE = 0, C_MEM_READ = 1, C_MEM_WRITE = 2, C_BRANCH = 3, C_BRANCH_GT = 4,
              C_JUMP = 5, C_IS_CALL = 6, C_IS_RET = 7, C_ALU_SRC_IMM = 8, C_MEM_TO_REG = 9,
              C_FLAGS_WRITE = 10, C_RS1_VALID = 11, C_RS2_VALID = 12, C_ALU_OP = 13;

constexpr uint32_t CTRL_BUBBLE = ALU_NOP << C_ALU_OP;
constexpr uint32_t NOP_INSTR = 0x68000000;
constexpr uint32_t REG_SP = 14, REG_RA = 15;
constexpr uint32_t FWD_NONE = 0, FWD_EX_MEM = 1, FWD_MEM_WB = 2;

inline bool bit(uint32_t v, int n) { return (v >> n) & 1; }
inline uint32_t alu_op_of(uint32_t ctrl) { return (ctrl >> C_ALU_OP) & 0xF; }
inline uint32_t sign_extend27(uint32_t v) { return (uint32_t)((int32_t)(v << 5) >> 5); }
