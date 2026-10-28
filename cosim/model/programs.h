#pragma once
#include <cstdlib>
#include <string>
#include <utility>
#include <vector>
#include "alu.h"
#include "asm.h"
#include "decoder.h"
#include "rng.h"

constexpr uint32_t DATA_BASE = 0x400;
constexpr uint32_t STACK_TOP = 0x800;
constexpr uint32_t R_LOOP = 12;
constexpr uint32_t R_BASE = 13;
constexpr size_t MAX_WORDS = 1000;

struct Program {
    std::vector<uint32_t> code;
    std::string about;
};

class Builder {
public:
    std::vector<uint32_t> code;

    int label() {
        labels.push_back(-1);
        return (int)labels.size() - 1;
    }
    void bind(int l) { labels[l] = (int)code.size(); }
    void emit(uint32_t ins) { code.push_back(ins); }
    void jump(uint32_t op, int l) {
        fixups.push_back({code.size(), l});
        code.push_back(op << 27);
    }
    void halt() { code.push_back(enc_b(OP_B, 0)); }

    void resolve() {
        for (auto& f : fixups) {
            int32_t offset = labels[f.second] - (int32_t)f.first;
            code[f.first] |= (uint32_t)offset & 0x7FFFFFF;
        }
    }

private:
    std::vector<int> labels;
    std::vector<std::pair<size_t, int>> fixups;
};

inline void load_const(Builder& b, uint32_t reg, uint32_t value) {
    int32_t s = (int32_t)value;
    if (s >= -32768 && s <= 32767) {
        b.emit(enc_i(OP_MOV, reg, 0, value));
    } else {
        b.emit(enc_i(OP_MOV, reg, 0, value >> 16, 2));
        b.emit(enc_i(OP_OR, reg, reg, value & 0xFFFF, 1));
    }
}

inline void prologue(Builder& b) {
    b.emit(enc_i(OP_MOV, R_BASE, 0, DATA_BASE));
    b.emit(enc_i(OP_MOV, REG_SP, 0, STACK_TOP));
}

const std::vector<uint32_t> ALU_OPS = {OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_AND, OP_OR, OP_LSL, OP_LSR, OP_ASR};

class RandomProgram {
public:
    explicit RandomProgram(Rng& r) : rng(r) {}

    Program make() {
        static const char* profile_names[] = {"alu", "memory", "branch"};
        static const int profiles[3][KINDS] = {
            {30, 20, 6, 8, 6, 5, 3, 8, 3, 2, 3},
            {12, 10, 4, 6, 18, 15, 10, 8, 3, 2, 3},
            {14, 10, 4, 18, 6, 5, 3, 22, 6, 2, 5},
        };

        for (;;) {
            b = Builder();
            int profile = rng.below(3);
            for (int k = 0; k < KINDS; k++)
                weight[k] = profiles[profile][k];

            std::vector<uint32_t> all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
            rng.shuffle(all);
            int pool = rng.range(2, 12);
            wregs.assign(all.begin(), all.begin() + pool);

            int nsubs = rng.below(4);
            subs.clear();
            for (int i = 0; i < nsubs; i++)
                subs.push_back(b.label());

            prologue(b);
            for (uint32_t r : wregs)
                load_const(b, r, interesting(rng));
            block(rng.range(30, 200), {true, 0});
            b.halt();

            for (int i = 0; i < nsubs; i++) {
                b.bind(subs[i]);
                bool can_call = i + 1 < nsubs && rng.chance(60);
                bool save_ra = can_call || rng.chance(40);

                if (rng.chance(50))
                    read_ra_soon();
                if (save_ra) {
                    if (rng.chance(50)) {
                        b.emit(enc_i(OP_SUB, REG_SP, REG_SP, 4));
                        b.emit(enc_i(OP_ST, REG_RA, REG_SP, 0));
                    } else {
                        b.emit(enc_i(OP_ST, REG_RA, REG_SP, 0xFFFC));
                        b.emit(enc_i(OP_SUB, REG_SP, REG_SP, 4));
                    }
                }
                block(rng.range(save_ra ? 3 : 0, 20), {false, can_call ? i + 1 : nsubs});
                if (save_ra) {
                    if (rng.chance(50)) {
                        b.emit(enc_i(OP_LD, REG_RA, REG_SP, 0));
                        b.emit(enc_i(OP_ADD, REG_SP, REG_SP, 4));
                    } else {
                        b.emit(enc_i(OP_ADD, REG_SP, REG_SP, 4));
                        b.emit(enc_i(OP_LD, REG_RA, REG_SP, 0xFFFC));
                    }
                }
                if (rng.chance(50))
                    rewrite_ra();
                int gap = rng.below(3);
                for (int k = 0; k < gap; k++)
                    alu_instr(wreg());
                b.emit(enc_r(OP_RET, 0, 0, 0));
            }

            b.resolve();
            if (b.code.size() <= MAX_WORDS) {
                std::string about = std::string("random, ") + profile_names[profile] + " profile, " +
                                    std::to_string(pool) + " registers, " + std::to_string(nsubs) + " subroutines";
                return {b.code, about};
            }
        }
    }

private:
    enum Kind { ALU_R, ALU_I, MOVNOT, CMP, LD, ST, PTR, BRANCH, CALL, NOP, LOOP, KINDS };
    struct Ctx {
        bool loops_ok;
        int first_callee;
    };

    Rng& rng;
    Builder b;
    std::vector<uint32_t> wregs;
    std::vector<int> subs;
    int weight[KINDS];

    uint32_t wreg() { return rng.pick(wregs); }
    uint32_t rreg() { return rng.chance(85) ? rng.pick(wregs) : rng.below(16); }

    uint32_t wreg_except(uint32_t avoid) {
        uint32_t r;
        do {
            r = wreg();
        } while (r == avoid);
        return r;
    }

    uint32_t imm_for(uint32_t op, uint32_t& mod) {
        mod = rng.chance(80) ? 0 : rng.range(1, 2);
        if (op == OP_LSL || op == OP_LSR || op == OP_ASR) {
            mod = 0;
            return rng.below(36);
        }
        switch (rng.below(5)) {
        case 0:  return rng.below(16);
        case 1:  return (uint32_t)-(int32_t)rng.range(1, 16) & 0xFFFF;
        case 2:  return rng.pick(std::vector<uint32_t>{0, 1, 0x7FFF, 0x8000, 0xFFFF});
        default: return rng.below(0x10000);
        }
    }

    Kind choose(const Ctx& ctx) {
        int w[KINDS];
        int total = 0;
        for (int k = 0; k < KINDS; k++) {
            w[k] = weight[k];
            if (k == CALL && ctx.first_callee >= (int)subs.size()) w[k] = 0;
            if (k == LOOP && !ctx.loops_ok) w[k] = 0;
            total += w[k];
        }
        int x = rng.below(total);
        for (int k = 0; k < KINDS; k++) {
            if (x < w[k])
                return (Kind)k;
            x -= w[k];
        }
        return ALU_R;
    }

    void alu_instr(uint32_t rd) {
        uint32_t op = rng.pick(ALU_OPS);
        if (rng.chance(55)) {
            b.emit(enc_r(op, rd, rreg(), rreg()));
        } else {
            uint32_t mod;
            uint32_t imm = imm_for(op, mod);
            b.emit(enc_i(op, rd, rreg(), imm, mod));
        }
    }

    void read_ra_soon() {
        int gap = rng.below(3);
        for (int k = 0; k < gap; k++)
            alu_instr(wreg());
        uint32_t op = rng.pick(ALU_OPS);
        switch (rng.below(5)) {
        case 0: b.emit(enc_r(op, wreg(), REG_RA, rreg())); break;
        case 1: b.emit(enc_r(op, wreg(), rreg(), REG_RA)); break;
        case 2: b.emit(enc_r(OP_CMP, 0, REG_RA, rreg())); break;
        case 3: b.emit(enc_r(rng.chance(50) ? OP_MOV : OP_NOT, wreg(), 0, REG_RA)); break;
        default: b.emit(enc_i(OP_LD, wreg(), REG_RA, 0)); break;
        }
    }

    void rewrite_ra() {
        const uint32_t ra = REG_RA;
        switch (rng.below(13)) {
        case 0:  b.emit(enc_i(OP_ADD, ra, ra, 0)); break;
        case 1:  b.emit(enc_i(OP_SUB, ra, ra, 0)); break;
        case 2:  b.emit(enc_i(OP_MUL, ra, ra, 1)); break;
        case 3:  b.emit(enc_i(OP_DIV, ra, ra, 1)); break;
        case 4:  b.emit(enc_i(OP_MOD, ra, ra, 0x7FFF)); break;
        case 5:  b.emit(enc_i(OP_AND, ra, ra, 0xFFFF)); break;
        case 6:  b.emit(enc_i(OP_OR, ra, ra, 0)); break;
        case 7:  b.emit(enc_i(OP_LSL, ra, ra, 0)); break;
        case 8:  b.emit(enc_i(OP_LSR, ra, ra, 0)); break;
        case 9:  b.emit(enc_i(OP_ASR, ra, ra, 0)); break;
        case 10: b.emit(enc_r(OP_MOV, ra, 0, ra)); break;
        case 11:
            b.emit(enc_r(OP_NOT, ra, 0, ra));
            b.emit(enc_r(OP_NOT, ra, 0, ra));
            break;
        default:
            b.emit(enc_i(OP_ST, ra, REG_SP, 0xFFF8));
            b.emit(enc_i(OP_LD, ra, REG_SP, 0xFFF8));
            break;
        }
    }

    void block(int steps, Ctx ctx) {
        std::vector<std::pair<int, int>> pending;
        for (int k = 0; k < steps; k++) {
            for (size_t i = 0; i < pending.size();) {
                if (pending[i].second == k) {
                    b.bind(pending[i].first);
                    pending.erase(pending.begin() + i);
                } else {
                    i++;
                }
            }

            Kind kind = choose(ctx);
            if (kind == BRANCH) {
                int l = b.label();
                b.jump(rng.pick(std::vector<uint32_t>{OP_BEQ, OP_BEQ, OP_BGT, OP_BGT, OP_B}), l);
                pending.push_back({l, k + 1 + (int)rng.below(4)});
            } else {
                emit(kind, ctx);
            }
        }
        for (auto& p : pending)
            b.bind(p.first);
    }

    void emit(Kind kind, const Ctx& ctx) {
        uint32_t mod;
        switch (kind) {
        case ALU_R:
        case ALU_I:
            alu_instr(wreg());
            break;

        case MOVNOT: {
            uint32_t op = rng.chance(50) ? OP_MOV : OP_NOT;
            if (rng.chance(50)) {
                b.emit(enc_r(op, wreg(), 0, rreg()));
            } else {
                uint32_t imm = imm_for(op, mod);
                b.emit(enc_i(op, wreg(), 0, imm, mod));
            }
            break;
        }

        case CMP:
            if (rng.chance(20)) {
                uint32_t r = rreg();
                b.emit(enc_r(OP_CMP, 0, r, r));
            } else if (rng.chance(50)) {
                b.emit(enc_r(OP_CMP, 0, rreg(), rreg()));
            } else {
                uint32_t imm = imm_for(OP_CMP, mod);
                b.emit(enc_i(OP_CMP, 0, rreg(), imm, mod));
            }
            break;

        case LD:
            b.emit(enc_i(OP_LD, wreg(), R_BASE, 4 * rng.below(64)));
            break;

        case ST:
            b.emit(enc_i(OP_ST, rreg(), R_BASE, 4 * rng.below(64)));
            break;

        case PTR: {
            uint32_t p = wreg();
            b.emit(enc_i(OP_ADD, p, R_BASE, 4 * rng.below(32)));
            int fillers = rng.below(3);
            for (int i = 0; i < fillers; i++)
                alu_instr(wreg_except(p));
            if (rng.chance(50))
                b.emit(enc_i(OP_LD, wreg(), p, 4 * rng.below(32)));
            else
                b.emit(enc_i(OP_ST, rreg(), p, 4 * rng.below(32)));
            break;
        }

        case CALL:
            b.jump(OP_CALL, subs[rng.range(ctx.first_callee, (uint32_t)subs.size() - 1)]);
            break;

        case NOP:
            b.emit(NOP_INSTR);
            break;

        case LOOP: {
            b.emit(enc_i(OP_MOV, R_LOOP, 0, rng.range(1, 4)));
            int top = b.label();
            b.bind(top);
            block(rng.range(3, 10), {false, ctx.first_callee});
            b.emit(enc_i(OP_SUB, R_LOOP, R_LOOP, 1));
            b.emit(enc_i(OP_CMP, 0, R_LOOP, 0));
            b.jump(OP_BGT, top);
            break;
        }

        default:
            break;
        }
    }
};

struct Use {
    uint32_t op;
    int slot;
};

enum { SLOT_RS1 = 1, SLOT_RS2, SLOT_STORE_DATA, SLOT_BASE };

inline void operands_for_address(Rng& rng, uint32_t op, uint32_t addr, uint32_t& a, uint32_t& b) {
    uint32_t t = rng.range(1, 200);
    switch (op) {
    case OP_ADD: a = addr - t; b = t; break;
    case OP_SUB: a = addr + t; b = t; break;
    case OP_MUL: a = addr / 4; b = 4; break;
    case OP_DIV: a = addr * 4; b = 4; break;
    case OP_MOD: a = addr + 0x10000 * rng.range(1, 5); b = 0x10000; break;
    case OP_AND: a = addr | 0xABCD0000; b = 0xFFFF; break;
    case OP_OR:  a = addr & 0xFF00; b = addr & 0x00FF; break;
    case OP_LSL: a = addr >> 2; b = 2; break;
    case OP_LSR: a = addr << 3; b = 3; break;
    case OP_ASR: a = addr << 4; b = 4; break;
    case OP_NOT: a = ~addr; break;
    default:     a = addr; break;
    }
}

inline uint32_t produced_value(uint32_t op, uint32_t a, uint32_t b) {
    if (op == OP_LD || op == OP_MOV) return a;
    if (op == OP_NOT) return ~a;
    return alu(a, b, alu_op_for(op));
}

inline void fillers(Builder& b, Rng& rng, int n) {
    for (int i = 0; i < n; i++)
        b.emit(rng.chance(50) ? NOP_INSTR : enc_i(OP_ADD, 11, 11, 1));
}

inline void pair_snippet(Builder& b, Rng& rng, uint32_t producer, Use use, int distance) {
    std::vector<uint32_t> regs = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    rng.shuffle(regs);
    uint32_t x = regs[0], ra = regs[1], rb = regs[2], y = regs[3], dst = regs[4];

    uint32_t a = interesting(rng);
    uint32_t bv = interesting(rng);
    if (producer == OP_LSL || producer == OP_LSR || producer == OP_ASR)
        bv = rng.below(32);

    if (use.slot == SLOT_BASE) {
        uint32_t addr = DATA_BASE + 4 * rng.below(32);
        operands_for_address(rng, producer, addr, a, bv);
        if (produced_value(producer, a, bv) != addr) {
            fprintf(stderr, "pair generator: bad address operands for %s\n", op_name(producer));
            exit(1);
        }
    }
    uint32_t value = produced_value(producer, a, bv);

    load_const(b, x, interesting(rng));
    load_const(b, y, use.op == OP_CMP && rng.chance(35) ? value : interesting(rng));
    load_const(b, ra, a);
    load_const(b, rb, bv);

    if (producer == OP_LD) {
        uint32_t off = 4 * rng.below(64);
        b.emit(enc_i(OP_ST, ra, R_BASE, off));
        b.emit(enc_i(OP_LD, x, R_BASE, off));
    } else if (producer == OP_NOT || producer == OP_MOV) {
        b.emit(enc_r(producer, x, 0, ra));
    } else {
        b.emit(enc_r(producer, x, ra, rb));
    }

    fillers(b, rng, distance - 1);

    switch (use.slot) {
    case SLOT_RS1:
        b.emit(enc_r(use.op, use.op == OP_CMP ? 0 : dst, x, y));
        break;
    case SLOT_RS2:
        if (use.op == OP_NOT || use.op == OP_MOV)
            b.emit(enc_r(use.op, dst, 0, x));
        else
            b.emit(enc_r(use.op, use.op == OP_CMP ? 0 : dst, y, x));
        break;
    case SLOT_STORE_DATA:
        b.emit(enc_i(OP_ST, x, R_BASE, 4 * rng.below(64)));
        break;
    case SLOT_BASE:
        if (use.op == OP_LD)
            b.emit(enc_i(OP_LD, dst, x, 4 * rng.below(32)));
        else
            b.emit(enc_i(OP_ST, y, x, 4 * rng.below(32)));
        break;
    }

    if (use.op == OP_CMP) {
        int skip = b.label();
        b.jump(rng.chance(50) ? OP_BEQ : OP_BGT, skip);
        b.emit(enc_i(OP_ADD, dst, dst, 1));
        b.bind(skip);
    }
}

inline void flag_snippet(Builder& b, Rng& rng, uint32_t branch, bool imm_form, int relation, int distance) {
    std::vector<uint32_t> regs = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    rng.shuffle(regs);
    uint32_t y = regs[0], z = regs[1], dst = regs[2];

    uint32_t imm = rng.below(0x10000);
    uint32_t rhs = imm_form ? extend_imm(imm, 0) : interesting(rng);
    uint32_t lhs = rhs;
    if (relation == 1) lhs = rhs + rng.range(1, 100);
    if (relation == 2) lhs = rhs - rng.range(1, 100);

    load_const(b, y, lhs);
    if (imm_form)
        b.emit(enc_i(OP_CMP, 0, y, imm));
    else {
        load_const(b, z, rhs);
        b.emit(enc_r(OP_CMP, 0, y, z));
    }
    fillers(b, rng, distance - 1);

    int skip = b.label();
    b.jump(branch, skip);
    b.emit(enc_i(OP_ADD, dst, dst, 1));
    b.bind(skip);
}

inline std::vector<Program> pair_programs(Rng& rng) {
    const std::vector<uint32_t> producers = {OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_AND, OP_OR,
                                             OP_LSL, OP_LSR, OP_ASR, OP_NOT, OP_MOV, OP_LD};
    std::vector<Use> uses;
    for (uint32_t op : ALU_OPS) {
        uses.push_back({op, SLOT_RS1});
        uses.push_back({op, SLOT_RS2});
    }
    uses.push_back({OP_CMP, SLOT_RS1});
    uses.push_back({OP_CMP, SLOT_RS2});
    uses.push_back({OP_NOT, SLOT_RS2});
    uses.push_back({OP_MOV, SLOT_RS2});
    uses.push_back({OP_ST, SLOT_STORE_DATA});
    uses.push_back({OP_LD, SLOT_BASE});
    uses.push_back({OP_ST, SLOT_BASE});

    std::vector<Program> progs;
    Builder b;
    int combos = 0;
    auto start = [&]() {
        b = Builder();
        prologue(b);
        combos = 0;
    };
    auto finish = [&]() {
        b.halt();
        b.resolve();
        progs.push_back({b.code, "directed pairs, " + std::to_string(combos) + " combinations"});
    };

    start();
    for (uint32_t p : producers) {
        for (const Use& u : uses) {
            for (int d = 1; d <= 3; d++) {
                if (b.code.size() > 900) {
                    finish();
                    start();
                }
                pair_snippet(b, rng, p, u, d);
                combos++;
            }
        }
    }
    for (uint32_t br : {OP_BEQ, OP_BGT}) {
        for (int imm_form = 0; imm_form < 2; imm_form++) {
            for (int rel = 0; rel < 3; rel++) {
                for (int d = 1; d <= 3; d++) {
                    if (b.code.size() > 900) {
                        finish();
                        start();
                    }
                    flag_snippet(b, rng, br, imm_form, rel, d);
                    combos++;
                }
            }
        }
    }
    finish();
    return progs;
}
