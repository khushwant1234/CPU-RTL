#pragma once
#include "defines.h"

class RegFile {
public:
    void reset() {
        for (auto& r : regs)
            r = 0;
    }

    uint32_t read(uint32_t addr, bool we, uint32_t waddr, uint32_t wdata) const {
        return (we && waddr == addr) ? wdata : regs[addr];
    }

    void write(uint32_t addr, uint32_t data) { regs[addr] = data; }

private:
    uint32_t regs[16] = {};
};
