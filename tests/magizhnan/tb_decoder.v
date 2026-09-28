`timescale 1ns/1ps
`include "defines.vh"

module tb_decoder;

reg [31:0] instr;
wire [3:0] rd_addr, rs1_addr, rs2_addr;
wire [31:0] imm_ext;
wire [26:0] branch_offset;
wire [`CTRL_W-1:0] ctrl;

reg [`CTRL_W-1:0] exp;
reg [4:0] alu_ops [0:9];
reg [3:0] alu_exp [0:9];
integer i;

decoder dut(
    .instr(instr),
    .rd_addr(rd_addr),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .imm_ext(imm_ext),
    .branch_offset(branch_offset),
    .ctrl(ctrl)
);

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
        $display("      inputs  : instr=%h (opcode=%b)", instr, instr[31:27]);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

function [31:0] enc_r;
    input [4:0] op;
    input [3:0] rd, rs1, rs2;
    enc_r = {op, 1'b0, rd, rs1, rs2, 14'b0};
endfunction

function [31:0] enc_i;
    input [4:0] op;
    input [3:0] rd, rs1;
    input [15:0] imm;
    input [1:0] mod;
    enc_i = {op, 1'b1, rd, rs1, mod, imm};
endfunction

function [31:0] enc_b;
    input [4:0] op;
    input [26:0] offset;
    enc_b = {op, offset};
endfunction

initial begin
    $display("tb_decoder");

    alu_ops[0] = `OP_ADD; alu_exp[0] = `ALU_ADD;
    alu_ops[1] = `OP_SUB; alu_exp[1] = `ALU_SUB;
    alu_ops[2] = `OP_MUL; alu_exp[2] = `ALU_MUL;
    alu_ops[3] = `OP_DIV; alu_exp[3] = `ALU_DIV;
    alu_ops[4] = `OP_MOD; alu_exp[4] = `ALU_MOD;
    alu_ops[5] = `OP_AND; alu_exp[5] = `ALU_AND;
    alu_ops[6] = `OP_OR;  alu_exp[6] = `ALU_OR;
    alu_ops[7] = `OP_LSL; alu_exp[7] = `ALU_LSL;
    alu_ops[8] = `OP_LSR; alu_exp[8] = `ALU_LSR;
    alu_ops[9] = `OP_ASR; alu_exp[9] = `ALU_ASR;

    for (i = 0; i < 10; i = i + 1) begin
        instr = enc_r(alu_ops[i], 1, 2, 3);
        #1;
        exp = `CTRL_BUBBLE;
        exp[`C_REG_WRITE] = 1;
        exp[`C_RS1_VALID] = 1;
        exp[`C_RS2_VALID] = 1;
        exp[`C_ALU_OP] = alu_exp[i];
        check(rd_addr, 1, "alu register form: rd");
        check(rs1_addr, 2, "alu register form: rs1");
        check(rs2_addr, 3, "alu register form: rs2");
        check(ctrl, exp, "alu register form: ctrl");
    end

    for (i = 0; i < 10; i = i + 1) begin
        instr = enc_i(alu_ops[i], 4, 5, 100, 2'b00);
        #1;
        exp = `CTRL_BUBBLE;
        exp[`C_REG_WRITE] = 1;
        exp[`C_RS1_VALID] = 1;
        exp[`C_ALU_SRC_IMM] = 1;
        exp[`C_ALU_OP] = alu_exp[i];
        check(rd_addr, 4, "alu immediate form: rd");
        check(rs1_addr, 5, "alu immediate form: rs1");
        check(imm_ext, 100, "alu immediate form: imm");
        check(ctrl, exp, "alu immediate form: ctrl (rs2_valid = 0)");
    end

    instr = enc_i(`OP_ADD, 1, 2, 16'hFFFD, 2'b00);
    #1;
    check(imm_ext, 32'hFFFFFFFD, "default modifier sign extends -3");
    instr = enc_i(`OP_ADD, 1, 2, 16'h7FFF, 2'b00);
    #1;
    check(imm_ext, 32'h00007FFF, "default modifier positive max");
    instr = enc_i(`OP_ADD, 1, 2, 16'hFFFD, 2'b01);
    #1;
    check(imm_ext, 32'h0000FFFD, "u modifier zero extends");
    instr = enc_i(`OP_MOV, 1, 0, 16'hABCD, 2'b10);
    #1;
    check(imm_ext, 32'hABCD0000, "h modifier upper half");
    instr = enc_i(`OP_ADD, 1, 2, 16'h1234, 2'b11);
    #1;
    check(imm_ext, 0, "modifier 11 gives 0");

    instr = enc_r(`OP_CMP, 0, 6, 7);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1;
    exp[`C_RS2_VALID] = 1;
    exp[`C_FLAGS_WRITE] = 1;
    exp[`C_ALU_OP] = `ALU_CMP;
    check(rs1_addr, 6, "cmp: rs1");
    check(rs2_addr, 7, "cmp: rs2");
    check(ctrl, exp, "cmp register form: ctrl");

    instr = enc_i(`OP_CMP, 0, 6, 9, 2'b00);
    #1;
    exp[`C_RS2_VALID] = 0;
    exp[`C_ALU_SRC_IMM] = 1;
    check(ctrl, exp, "cmp immediate form: ctrl");

    instr = enc_r(`OP_NOT, 3, 0, 4);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_REG_WRITE] = 1;
    exp[`C_RS2_VALID] = 1;
    exp[`C_ALU_OP] = `ALU_NOT;
    check(rd_addr, 3, "not: rd");
    check(rs2_addr, 4, "not: source on rs2");
    check(ctrl, exp, "not register form: ctrl");

    instr = enc_r(`OP_MOV, 9, 0, 10);
    #1;
    exp[`C_ALU_OP] = `ALU_MOV;
    check(rd_addr, 9, "mov: rd");
    check(rs2_addr, 10, "mov: source on rs2");
    check(ctrl, exp, "mov register form: ctrl");

    instr = enc_i(`OP_MOV, 9, 0, 42, 2'b00);
    #1;
    exp[`C_RS2_VALID] = 0;
    exp[`C_ALU_SRC_IMM] = 1;
    check(imm_ext, 42, "mov immediate: imm");
    check(ctrl, exp, "mov immediate form: ctrl");

    instr = enc_i(`OP_LD, 1, 2, 8, 2'b00);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_REG_WRITE] = 1;
    exp[`C_RS1_VALID] = 1;
    exp[`C_MEM_READ] = 1;
    exp[`C_MEM_TO_REG] = 1;
    exp[`C_ALU_SRC_IMM] = 1;
    exp[`C_ALU_OP] = `ALU_ADD;
    check(rd_addr, 1, "ld: rd");
    check(rs1_addr, 2, "ld: base register");
    check(imm_ext, 8, "ld: offset");
    check(ctrl, exp, "ld: ctrl");

    instr = enc_i(`OP_ST, 6, 7, 16'hFFFC, 2'b00);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1;
    exp[`C_RS2_VALID] = 1;
    exp[`C_MEM_WRITE] = 1;
    exp[`C_ALU_SRC_IMM] = 1;
    exp[`C_ALU_OP] = `ALU_ADD;
    check(rs1_addr, 7, "st: base register on rs1");
    check(rs2_addr, 6, "st: stored register on rs2");
    check(imm_ext, 32'hFFFFFFFC, "st: negative offset");
    check(ctrl, exp, "st: ctrl (no reg write)");

    instr = enc_b(`OP_B, 27'h7FFFFFE);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_JUMP] = 1;
    check(branch_offset, 27'h7FFFFFE, "b: offset");
    check(ctrl, exp, "b: ctrl");

    instr = enc_b(`OP_CALL, 12);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_JUMP] = 1;
    exp[`C_IS_CALL] = 1;
    exp[`C_REG_WRITE] = 1;
    check(rd_addr, `REG_RA, "call: rd is r15");
    check(branch_offset, 12, "call: offset");
    check(ctrl, exp, "call: ctrl");

    instr = enc_b(`OP_BEQ, 3);
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_BRANCH] = 1;
    check(ctrl, exp, "beq: ctrl");
    check(branch_offset, 3, "beq: offset");

    instr = enc_b(`OP_BGT, 5);
    #1;
    exp[`C_BRANCH_GT] = 1;
    check(ctrl, exp, "bgt: ctrl");
    check(branch_offset, 5, "bgt: offset");

    instr = {`OP_RET, 27'b0};
    #1;
    exp = `CTRL_BUBBLE;
    exp[`C_RS1_VALID] = 1;
    exp[`C_IS_RET] = 1;
    check(rs1_addr, `REG_RA, "ret: rs1 is r15");
    check(ctrl, exp, "ret: ctrl");

    instr = `NOP_INSTR;
    #1;
    check(ctrl, `CTRL_BUBBLE, "nop: bubble");
    instr = {5'b11111, 27'h5A5A5A5};
    #1;
    check(ctrl, `CTRL_BUBBLE, "illegal opcode gives bubble");
    instr = {5'b10101, 27'h0};
    #1;
    check(ctrl, `CTRL_BUBBLE, "unused opcode 10101 gives bubble");

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
