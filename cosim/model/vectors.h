#pragma once
#include <cstdio>
#include <string>
#include "decoder.h"
#include "execute_stage.h"
#include "forwarding_unit.h"
#include "hazard_unit.h"
#include "reg_file.h"
#include "rng.h"
#include "writeback.h"

inline uint32_t random_instr(Rng& rng) {
    if (rng.chance(3))
        return NOP_INSTR;
    uint32_t opcode = rng.chance(90) ? rng.below(21) : rng.range(21, 31);
    return opcode << 27 | (rng.u32() & 0x7FFFFFF);
}

inline uint32_t random_ctrl(Rng& rng) {
    if (rng.chance(10))
        return rng.u32() & 0x1FFFF;
    return decode(random_instr(rng)).ctrl;
}

inline uint32_t small_reg(Rng& rng) {
    return rng.chance(75) ? rng.below(4) : rng.below(16);
}

inline bool gen_vector(const std::string& m, Rng& rng, FILE* f) {
    if (m == "decoder") {
        fprintf(f, "%08x\n", random_instr(rng));
    }
    else if (m == "alu") {
        uint32_t op = rng.chance(95) ? rng.below(14) : rng.range(14, 15);
        uint32_t a = interesting(rng);
        uint32_t b = interesting(rng);
        if ((op == ALU_LSL || op == ALU_LSR || op == ALU_ASR) && rng.chance(70))
            b = rng.below(40);
        if ((op == ALU_DIV || op == ALU_MOD) && rng.chance(30))
            b = rng.pick(std::vector<uint32_t>{0, 1, 2, 0xFFFFFFFF});
        if (rng.chance(10))
            b = a;
        fprintf(f, "%x %08x %08x\n", op, a, b);
    }
    else if (m == "branch_unit") {
        fprintf(f, "%x %x %x %x %x %x %08x %08x\n", rng.below(2), rng.below(2), rng.below(2), rng.below(2),
                rng.below(2), rng.below(2), rng.u32() & ~3u, rng.u32() & ~3u);
    }
    else if (m == "execute_stage") {
        Decoded d = decode(random_instr(rng));
        uint32_t ctrl = rng.chance(10) ? rng.u32() & 0x1FFFF : d.ctrl;
        uint32_t op1 = interesting(rng);
        uint32_t op2 = rng.chance(15) ? op1 : interesting(rng);
        if (rng.chance(10))
            op1 = d.imm;
        fprintf(f, "%08x %08x %08x %08x %07x %05x\n", rng.u32() & ~3u, op1, op2, d.imm, d.offset, ctrl);
    }
    else if (m == "forwarding_unit") {
        fprintf(f, "%x %x %x %x %08x %08x %x %x %x %08x %x %x %08x\n",
                small_reg(rng), small_reg(rng), rng.below(2), rng.below(2), rng.u32(), rng.u32(),
                small_reg(rng), rng.below(2), rng.chance(25), rng.u32(),
                small_reg(rng), rng.below(2), rng.u32());
    }
    else if (m == "hazard_unit") {
        fprintf(f, "%x %x %x %x %x %x %x\n", small_reg(rng), small_reg(rng), rng.below(2), rng.below(2),
                rng.chance(40), small_reg(rng), rng.chance(20));
    }
    else if (m == "writeback") {
        fprintf(f, "%08x %08x %08x %x %05x\n", rng.u32() & ~3u, rng.u32(), rng.u32(), rng.below(16), random_ctrl(rng));
    }
    else if (m == "reg_file") {
        uint32_t waddr = rng.below(16);
        uint32_t rs1 = rng.chance(30) ? waddr : rng.below(16);
        uint32_t rs2 = rng.chance(30) ? waddr : rng.below(16);
        fprintf(f, "%x %x %x %08x %x %x\n", !rng.chance(1), rng.chance(60), waddr, interesting(rng), rs1, rs2);
    }
    else {
        return false;
    }
    return true;
}

inline bool run_model(const std::string& m, FILE* in, FILE* out) {
    if (m == "decoder") {
        uint32_t instr;
        while (fscanf(in, "%x", &instr) == 1) {
            Decoded d = decode(instr);
            fprintf(out, "%08x -> rd=%x rs1=%x rs2=%x imm=%08x off=%07x ctrl=%05x\n",
                    instr, d.rd, d.rs1, d.rs2, d.imm, d.offset, d.ctrl);
        }
    }
    else if (m == "alu") {
        uint32_t op, a, b;
        while (fscanf(in, "%x %x %x", &op, &a, &b) == 3)
            fprintf(out, "op=%x a=%08x b=%08x -> %08x\n", op, a, b, alu(a, b, op));
    }
    else if (m == "branch_unit") {
        uint32_t j, br, gt, ret, e, g, target, ra;
        while (fscanf(in, "%x %x %x %x %x %x %x %x", &j, &br, &gt, &ret, &e, &g, &target, &ra) == 8) {
            BranchOut o = branch_unit(j, br, gt, ret, e, g, target, ra);
            fprintf(out, "j=%x br=%x gt=%x ret=%x e=%x g=%x tgt=%08x ra=%08x -> taken=%x pc=%08x\n",
                    j, br, gt, ret, e, g, target, ra, o.taken, o.pc);
        }
    }
    else if (m == "execute_stage") {
        ExecuteStage ex;
        uint32_t pc, op1, op2, imm, offset, ctrl;
        while (fscanf(in, "%x %x %x %x %x %x", &pc, &op1, &op2, &imm, &offset, &ctrl) == 6) {
            ExOut o = ex.eval(pc, op1, op2, imm, offset, ctrl);
            fprintf(out, "pc=%08x op1=%08x op2=%08x imm=%08x off=%07x ctrl=%05x -> res=%08x e=%x gt=%x taken=%x bpc=%08x\n",
                    pc, op1, op2, imm, offset, ctrl, o.alu_result, o.flag_e, o.flag_gt, o.taken, o.branch_pc);
            ex.clock(op1, op2, imm, ctrl);
        }
    }
    else if (m == "forwarding_unit") {
        uint32_t v[13];
        while (fscanf(in, "%x %x %x %x %x %x %x %x %x %x %x %x %x", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5],
                      &v[6], &v[7], &v[8], &v[9], &v[10], &v[11], &v[12]) == 13) {
            FwdIn in_ = {v[0], v[1], (bool)v[2], (bool)v[3], v[4], v[5], v[6], (bool)v[7], (bool)v[8], v[9],
                         v[10], (bool)v[11], v[12]};
            FwdOut o = forwarding_unit(in_);
            fprintf(out, "rs1=%x rs2=%x v1=%x v2=%x d1=%08x d2=%08x mrd=%x mw=%x mld=%x md=%08x wrd=%x ww=%x wd=%08x"
                         " -> a=%x b=%x op1=%08x op2=%08x\n",
                    v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12],
                    o.sel_a, o.sel_b, o.op1, o.op2);
        }
    }
    else if (m == "hazard_unit") {
        uint32_t rs1, rs2, v1, v2, ld, rd, taken;
        while (fscanf(in, "%x %x %x %x %x %x %x", &rs1, &rs2, &v1, &v2, &ld, &rd, &taken) == 7) {
            HazardOut h = hazard_unit(rs1, rs2, v1, v2, ld, rd, taken);
            fprintf(out, "rs1=%x rs2=%x v1=%x v2=%x ld=%x rd=%x taken=%x -> lu=%x pcs=%x ifs=%x iff=%x idf=%x\n",
                    rs1, rs2, v1, v2, ld, rd, taken, h.load_use, h.pc_stall, h.if_id_stall, h.if_id_flush, h.id_ex_flush);
        }
    }
    else if (m == "writeback") {
        uint32_t pc, alu_res, ld_res, rd, ctrl;
        while (fscanf(in, "%x %x %x %x %x", &pc, &alu_res, &ld_res, &rd, &ctrl) == 5) {
            WbOut w = writeback(pc, alu_res, ld_res, rd, ctrl);
            fprintf(out, "pc=%08x alu=%08x ld=%08x rd=%x ctrl=%05x -> addr=%x data=%08x en=%x\n",
                    pc, alu_res, ld_res, rd, ctrl, w.addr, w.data, w.en);
        }
    }
    else if (m == "reg_file") {
        RegFile rf;
        uint32_t rst_n, we, waddr, wdata, rs1, rs2;
        while (fscanf(in, "%x %x %x %x %x %x", &rst_n, &we, &waddr, &wdata, &rs1, &rs2) == 6) {
            if (!rst_n)
                rf.reset();
            fprintf(out, "rst_n=%x we=%x wa=%x wd=%08x rs1=%x rs2=%x -> d1=%08x d2=%08x\n", rst_n, we, waddr, wdata,
                    rs1, rs2, rf.read(rs1, we, waddr, wdata), rf.read(rs2, we, waddr, wdata));
            if (rst_n && we)
                rf.write(waddr, wdata);
        }
    }
    else {
        return false;
    }
    return true;
}
