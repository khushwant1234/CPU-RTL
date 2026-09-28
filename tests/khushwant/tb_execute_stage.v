`timescale 1ns/1ps
`include "defines.vh"

module tb_execute_stage;

reg clk = 0;
reg rst_n;
reg [31:0] pc = 0, op1 = 0, op2 = 0, imm_ext = 0;
reg [26:0] branch_offset = 0;
reg [`CTRL_W-1:0] ctrl;
wire [31:0] alu_result, branch_pc;
wire flag_e, flag_gt, branch_taken;

execute_stage dut(
    .clk(clk),
    .rst_n(rst_n),
    .pc(pc),
    .op1(op1),
    .op2(op2),
    .imm_ext(imm_ext),
    .branch_offset(branch_offset),
    .ctrl(ctrl),
    .alu_result(alu_result),
    .flag_e(flag_e),
    .flag_gt(flag_gt),
    .branch_taken(branch_taken),
    .branch_pc(branch_pc)
);

always #5 clk = ~clk;

integer errors = 0;
integer tests = 0;
integer failed [0:255];
integer k;

task check;
    input [31:0] got;
    input [31:0] expected;
    input [8*64-1:0] name;
    begin
        tests = tests + 1;
        if (got === expected) begin
            $display("PASS  #%0d  %0s", tests, name);
        end
        else begin
            if (errors < 256)
                failed[errors] = tests;
            errors = errors + 1;
            $display("FAIL  #%0d  %0s   <-------", tests, name);
        end
        $display("      inputs  : ctrl=%b pc=%h op1=%h op2=%h imm_ext=%h branch_offset=%h", ctrl, pc, op1, op2, imm_ext, branch_offset);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

function [`CTRL_W-1:0] alu_ctrl;
    input [3:0] op;
    input imm;
    begin
        alu_ctrl = `CTRL_BUBBLE;
        alu_ctrl[`C_REG_WRITE] = 1;
        alu_ctrl[`C_RS1_VALID] = 1;
        alu_ctrl[`C_RS2_VALID] = !imm;
        alu_ctrl[`C_ALU_SRC_IMM] = imm;
        alu_ctrl[`C_ALU_OP] = op;
    end
endfunction

function [`CTRL_W-1:0] cmp_ctrl;
    input imm;
    begin
        cmp_ctrl = `CTRL_BUBBLE;
        cmp_ctrl[`C_FLAGS_WRITE] = 1;
        cmp_ctrl[`C_RS1_VALID] = 1;
        cmp_ctrl[`C_RS2_VALID] = !imm;
        cmp_ctrl[`C_ALU_SRC_IMM] = imm;
        cmp_ctrl[`C_ALU_OP] = `ALU_CMP;
    end
endfunction

function [`CTRL_W-1:0] br_ctrl;
    input gt;
    begin
        br_ctrl = `CTRL_BUBBLE;
        br_ctrl[`C_BRANCH] = 1;
        br_ctrl[`C_BRANCH_GT] = gt;
    end
endfunction

task do_cmp;
    input [31:0] x, y;
    begin
        ctrl = cmp_ctrl(0);
        op1 = x;
        op2 = y;
        @(posedge clk);
        #1;
        ctrl = `CTRL_BUBBLE;
    end
endtask

initial begin
    $display("tb_execute_stage");
    ctrl = `CTRL_BUBBLE;
    rst_n = 0;
    #2;
    rst_n = 1;

    ctrl = alu_ctrl(`ALU_ADD, 0);
    op1 = 5;
    op2 = 7;
    imm_ext = 100;
    #1;
    check(alu_result, 12, "add with register");
    check(branch_taken, 0, "add no branch");

    ctrl = alu_ctrl(`ALU_ADD, 1);
    #1;
    check(alu_result, 105, "add with immediate");

    ctrl = alu_ctrl(`ALU_SUB, 1);
    imm_ext = 32'hFFFFFFFF;
    #1;
    check(alu_result, 6, "sub with -1");

    ctrl = alu_ctrl(`ALU_MOV, 1);
    imm_ext = 32'hABCD0000;
    #1;
    check(alu_result, 32'hABCD0000, "mov immediate");

    ctrl = alu_ctrl(`ALU_ADD, 1);
    ctrl[`C_MEM_READ] = 1;
    op1 = 32'h100;
    imm_ext = 32'hFFFFFFFC;
    #1;
    check(alu_result, 32'hFC, "ld address negative offset");

    do_cmp(3, 3);
    check({flag_e, flag_gt}, 2'b10, "cmp equal");

    ctrl = alu_ctrl(`ALU_SUB, 0);
    op1 = 9;
    op2 = 1;
    @(posedge clk);
    #1;
    check({flag_e, flag_gt}, 2'b10, "sub does not change flags");

    pc = 32'h40;
    do_cmp(8, 8);
    ctrl = br_ctrl(0);
    branch_offset = 5;
    #1;
    check(branch_taken, 1, "beq taken");
    check(branch_pc, 32'h54, "beq target");

    ctrl = br_ctrl(1);
    #1;
    check(branch_taken, 0, "bgt not taken on equal");

    do_cmp(10, -2);
    ctrl = br_ctrl(1);
    branch_offset = -4;
    #1;
    check(branch_taken, 1, "bgt taken 10 > -2");
    check(branch_pc, 32'h30, "backward branch target");

    ctrl = br_ctrl(0);
    #1;
    check(branch_taken, 0, "beq not taken");

    ctrl = cmp_ctrl(1);
    op1 = 20;
    imm_ext = 20;
    @(posedge clk);
    #1;
    ctrl = br_ctrl(0);
    #1;
    check(branch_taken, 1, "cmp immediate then beq");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_JUMP] = 1;
    pc = 32'h200;
    branch_offset = 0;
    #1;
    check(branch_taken, 1, "b taken");
    check(branch_pc, 32'h200, "b to itself");

    ctrl[`C_IS_CALL] = 1;
    ctrl[`C_REG_WRITE] = 1;
    branch_offset = 16;
    #1;
    check(branch_taken, 1, "call taken");
    check(branch_pc, 32'h240, "call target");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_IS_RET] = 1;
    ctrl[`C_RS1_VALID] = 1;
    op1 = 32'h124;
    #1;
    check(branch_taken, 1, "ret taken");
    check(branch_pc, 32'h124, "ret target");

    ctrl = `CTRL_BUBBLE;
    #1;
    check(branch_taken, 0, "bubble no branch");
    check(alu_result, 0, "bubble alu result");

        $display("");
        $display("%0d checks, %0d passed, %0d failed", tests, tests - errors, errors);
        if (errors == 0) begin
            $display("TB_RESULT: PASS");
        end
        else begin
            $write("failed checks:");
            for (k = 0; k < errors && k < 256; k = k + 1)
                $write(" #%0d", failed[k]);
            $display("");
            $display("TB_RESULT: FAIL");
        end
        $finish;
end

endmodule
