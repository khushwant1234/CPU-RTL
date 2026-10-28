#pragma once
#include "defines.h"

struct BranchOut {
    bool taken;
    uint32_t pc;
};

inline BranchOut branch_unit(bool jump, bool branch, bool branch_gt, bool is_ret,
                             bool flag_e, bool flag_gt, uint32_t target, uint32_t ret_addr) {
    bool cond = branch_gt ? flag_gt : flag_e;
    return {jump || is_ret || (branch && cond), is_ret ? ret_addr : target};
}
