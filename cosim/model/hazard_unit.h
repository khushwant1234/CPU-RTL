#pragma once
#include "defines.h"

struct HazardOut {
    bool load_use;
    bool pc_stall;
    bool if_id_stall;
    bool if_id_flush;
    bool id_ex_flush;
};

inline HazardOut hazard_unit(uint32_t id_rs1, uint32_t id_rs2, bool rs1_valid, bool rs2_valid,
                             bool ex_load, uint32_t ex_rd, bool branch_taken) {
    bool rs1_match = rs1_valid && id_rs1 == ex_rd;
    bool rs2_match = rs2_valid && id_rs2 == ex_rd;
    bool load_use = ex_load && (rs1_match || rs2_match);

    HazardOut h;
    h.load_use = load_use;
    h.pc_stall = load_use && !branch_taken;
    h.if_id_stall = load_use && !branch_taken;
    h.if_id_flush = branch_taken;
    h.id_ex_flush = branch_taken || load_use;
    return h;
}
