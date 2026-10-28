#pragma once
#include "defines.h"

struct WbOut {
    uint32_t addr;
    uint32_t data;
    bool en;
};

inline WbOut writeback(uint32_t pc, uint32_t alu_result, uint32_t ld_result, uint32_t rd, uint32_t ctrl) {
    WbOut w;
    w.addr = bit(ctrl, C_IS_CALL) ? REG_RA : rd;
    if (bit(ctrl, C_IS_CALL))
        w.data = pc + 4;
    else if (bit(ctrl, C_MEM_TO_REG))
        w.data = ld_result;
    else
        w.data = alu_result;
    w.en = bit(ctrl, C_REG_WRITE);
    return w;
}
