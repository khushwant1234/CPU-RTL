module execute_stage (
    input [31:0] op1, op2, immx, branchTarget,
    input isImmediate,
    input isBeq, isBgt, isUBranch, isRet,
    input isAdd, isSub, isCmp, isMul, isDiv, isMod,
    input isLsl, isLsr, isAsr, isOr, isAnd, isNot, isMov,
    input clk, reset,
    output [31:0] aluResult,
    output flag_E, flag_GT,
    output isBranchTaken,
    output [31:0] branchPC
);
wire [31:0] alu_B;
assign alu_B = isImmediate ? immx : op2;

alu alu_unit (
    .A(op1), .B(alu_B),
    .isAdd(isAdd), .isSub(isSub), .isCmp(isCmp), .isMul(isMul),
    .isDiv(isDiv), .isMod(isMod), .isLsl(isLsl), .isLsr(isLsr),
    .isAsr(isAsr), .isOr(isOr), .isAnd(isAnd), .isNot(isNot), .isMov(isMov),
    .aluResult(aluResult)
);

flags flags_unit (
    .clk(clk), .reset(reset), .isCmp(isCmp),
    .A(op1), .B(alu_B), .flag_E(flag_E), .flag_GT(flag_GT)
);

branch_unit branch_unit_inst (
    .isUBranch(isUBranch), .isBeq(isBeq), .isBgt(isBgt), .isRet(isRet),
    .flag_E(flag_E), .flag_GT(flag_GT),
    .branchTarget(branchTarget), .op1(op1),
    .isBranchTaken(isBranchTaken), .branchPC(branchPC)
);
endmodule
