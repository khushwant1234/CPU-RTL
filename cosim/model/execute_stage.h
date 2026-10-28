#pragma once
#include "alu.h"
#include "branch_unit.h"

struct ExOut {
    uint32_t alu_result;
    bool flag_e;
    bool flag_gt;
    bool taken;
    uint32_t branch_pc;
};

class ExecuteStage {
public:
    void reset() { flag_e = flag_gt = false; }

    ExOut eval(uint32_t pc, uint32_t op1, uint32_t op2, uint32_t imm, uint32_t offset, uint32_t ctrl) const {
        uint32_t b = bit(ctrl, C_ALU_SRC_IMM) ? imm : op2;
        uint32_t target = pc + (sign_extend27(offset) << 2);
        BranchOut br = branch_unit(bit(ctrl, C_JUMP), bit(ctrl, C_BRANCH), bit(ctrl, C_BRANCH_GT),
                                   bit(ctrl, C_IS_RET), flag_e, flag_gt, target, op1);
        return {alu(op1, b, alu_op_of(ctrl)), flag_e, flag_gt, br.taken, br.pc};
    }

    void clock(uint32_t op1, uint32_t op2, uint32_t imm, uint32_t ctrl) {
        if (!bit(ctrl, C_FLAGS_WRITE))
            return;
        uint32_t b = bit(ctrl, C_ALU_SRC_IMM) ? imm : op2;
        flag_e = op1 == b;
        flag_gt = (int32_t)op1 > (int32_t)b;
    }

private:
    bool flag_e = false;
    bool flag_gt = false;
};
