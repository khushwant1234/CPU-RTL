module branch_unit (
    input isUBranch, isBeq, isBgt, isRet,
    input flag_E, flag_GT,
    input [31:0] branchTarget, op1,
    output isBranchTaken,
    output [31:0] branchPC
);
assign isBranchTaken = isUBranch | (isBeq & flag_E) | (isBgt & flag_GT);
assign branchPC = isRet ? op1 : branchTarget;
endmodule
