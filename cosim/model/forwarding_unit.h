#pragma once
#include "defines.h"

struct FwdIn {
    uint32_t ex_rs1, ex_rs2;
    bool rs1_valid, rs2_valid;
    uint32_t rs1_data, rs2_data;
    uint32_t mem_rd;
    bool mem_write, mem_load;
    uint32_t mem_data;
    uint32_t wb_rd;
    bool wb_write;
    uint32_t wb_data;
};

struct FwdOut {
    uint32_t sel_a, sel_b;
    uint32_t op1, op2;
};

inline uint32_t fwd_select(uint32_t src, bool valid, const FwdIn& in) {
    if (valid && in.mem_write && !in.mem_load && in.mem_rd == src)
        return FWD_EX_MEM;
    if (valid && in.wb_write && in.wb_rd == src)
        return FWD_MEM_WB;
    return FWD_NONE;
}

inline uint32_t fwd_value(uint32_t sel, uint32_t reg_value, const FwdIn& in) {
    if (sel == FWD_EX_MEM) return in.mem_data;
    if (sel == FWD_MEM_WB) return in.wb_data;
    return reg_value;
}

inline FwdOut forwarding_unit(const FwdIn& in) {
    FwdOut out;
    out.sel_a = fwd_select(in.ex_rs1, in.rs1_valid, in);
    out.sel_b = fwd_select(in.ex_rs2, in.rs2_valid, in);
    out.op1 = fwd_value(out.sel_a, in.rs1_data, in);
    out.op2 = fwd_value(out.sel_b, in.rs2_data, in);
    return out;
}
