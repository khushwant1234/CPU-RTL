#pragma once
#include <cstdio>
#include <string>
#include <vector>
#include "alu.h"
#include "asm.h"
#include "decoder.h"

struct Coverage {
    uint64_t instructions = 0;
    uint64_t count[32] = {};
    uint64_t taken = 0;
    uint64_t not_taken = 0;
    uint64_t load_use = 0;
    bool pair[32][32][4] = {};

    void report(FILE* f) const {
        fprintf(f, "  instructions executed : %llu\n", (unsigned long long)instructions);
        fprintf(f, "  per instruction       :");
        for (uint32_t op = 0; op <= OP_RET; op++) {
            if (op % 7 == 0 && op)
                fprintf(f, "\n                         ");
            fprintf(f, " %-4s %-7llu", op_name(op), (unsigned long long)count[op]);
        }
        fprintf(f, "\n  branches              : %llu taken, %llu not taken\n",
                (unsigned long long)taken, (unsigned long long)not_taken);
        fprintf(f, "  load-use pairs        : %llu\n", (unsigned long long)load_use);

        const std::vector<uint32_t> writers = {OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_AND, OP_OR,
                                               OP_LSL, OP_LSR, OP_ASR, OP_NOT, OP_MOV, OP_LD, OP_CALL};
        const std::vector<uint32_t> readers = {OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_AND, OP_OR, OP_LSL,
                                               OP_LSR, OP_ASR, OP_CMP, OP_NOT, OP_MOV, OP_LD, OP_ST, OP_RET};
        int hit[4] = {};
        for (uint32_t w : writers)
            for (uint32_t r : readers)
                for (int d = 1; d <= 3; d++)
                    hit[d] += pair[w][r][d];
        int possible = (int)(writers.size() * readers.size());
        fprintf(f, "  producer -> consumer  : distance 1: %d/%d, distance 2: %d/%d, distance 3: %d/%d\n",
                hit[1], possible, hit[2], possible, hit[3], possible);

        std::string missing;
        for (uint32_t w : writers)
            for (uint32_t r : readers)
                for (int d = 1; d <= 3; d++)
                    if (!pair[w][r][d])
                        missing += std::string(" ") + op_name(w) + "->" + op_name(r) + "@" + std::to_string(d);
        if (!missing.empty())
            fprintf(f, "  never hit             :%s\n", missing.c_str());
    }
};

class SimpleRisc {
public:
    explicit SimpleRisc(const std::vector<uint32_t>& program) : imem(program) {}

    void run(FILE* trace, Coverage& c, int64_t max_steps = 100000) {
        out = trace;
        cov = &c;
        for (int i = 0; i < 16; i++) {
            last_op[i] = -1;
            last_at[i] = -100;
        }

        for (step = 0; step < max_steps; step++) {
            uint32_t ins = fetch(pc);
            op = ins >> 27;
            bool imm_form = bit(ins, 26);
            uint32_t rd = (ins >> 22) & 0xF;
            uint32_t rs1 = (ins >> 18) & 0xF;
            uint32_t rs2 = (ins >> 14) & 0xF;
            uint32_t imm = extend_imm(ins & 0xFFFF, (ins >> 16) & 3);
            uint32_t target = pc + (sign_extend27(ins) << 2);
            uint32_t next = pc + 4;

            if (op == OP_B && target == pc) {
                fprintf(out, "H pc=%08x\n", pc);
                return;
            }
            c.instructions++;
            c.count[op]++;

            switch (op) {
            case OP_ADD: case OP_SUB: case OP_MUL: case OP_DIV: case OP_MOD:
            case OP_AND: case OP_OR:  case OP_LSL: case OP_LSR: case OP_ASR: {
                uint32_t a = read(rs1);
                uint32_t b = imm_form ? imm : read(rs2);
                write(rd, alu(a, b, alu_op_for(op)));
                break;
            }
            case OP_CMP: {
                uint32_t a = read(rs1);
                uint32_t b = imm_form ? imm : read(rs2);
                flag_e = a == b;
                flag_gt = (int32_t)a > (int32_t)b;
                break;
            }
            case OP_NOT:
                write(rd, ~(imm_form ? imm : read(rs2)));
                break;
            case OP_MOV:
                write(rd, imm_form ? imm : read(rs2));
                break;
            case OP_LD:
                write(rd, load(read(rs1) + imm));
                break;
            case OP_ST: {
                uint32_t addr = read(rs1) + imm;
                store(addr, read(rd));
                break;
            }
            case OP_BEQ:
            case OP_BGT: {
                bool cond = op == OP_BEQ ? flag_e : flag_gt;
                if (cond) {
                    next = target;
                    c.taken++;
                } else {
                    c.not_taken++;
                }
                break;
            }
            case OP_B:
                next = target;
                c.taken++;
                break;
            case OP_CALL:
                write(REG_RA, pc + 4);
                next = target;
                c.taken++;
                break;
            case OP_RET:
                next = read(REG_RA);
                c.taken++;
                break;
            default:
                break;
            }
            pc = next;
        }
        fprintf(out, "TIMEOUT\n");
    }

private:
    std::vector<uint32_t> imem;
    uint32_t r[16] = {};
    uint32_t dmem[1024] = {};
    bool flag_e = false;
    bool flag_gt = false;
    uint32_t pc = 0;
    uint32_t op = 0;
    int64_t step = 0;
    int64_t counted_load_use = -1;
    int last_op[16];
    int64_t last_at[16];
    FILE* out = nullptr;
    Coverage* cov = nullptr;

    uint32_t fetch(uint32_t addr) const {
        uint32_t i = addr >> 2;
        return i < imem.size() ? imem[i] : NOP_INSTR;
    }

    uint32_t load(uint32_t addr) const {
        uint32_t i = addr >> 2;
        return i < 1024 ? dmem[i] : 0;
    }

    void store(uint32_t addr, uint32_t value) {
        fprintf(out, "S pc=%08x mem[%08x]=%08x\n", pc, addr, value);
        if ((addr >> 2) < 1024)
            dmem[addr >> 2] = value;
    }

    uint32_t read(uint32_t reg) {
        int64_t d = step - last_at[reg];
        if (last_op[reg] >= 0 && d >= 1 && d <= 3) {
            cov->pair[last_op[reg]][op][d] = true;
            if (last_op[reg] == (int)OP_LD && d == 1 && counted_load_use != step) {
                cov->load_use++;
                counted_load_use = step;
            }
        }
        return r[reg];
    }

    void write(uint32_t rd, uint32_t value) {
        fprintf(out, "W pc=%08x r%u=%08x\n", pc, rd, value);
        r[rd] = value;
        last_op[rd] = (int)op;
        last_at[rd] = step;
    }
};
