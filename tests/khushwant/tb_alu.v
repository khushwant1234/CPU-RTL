`timescale 1ns/1ps
`include "defines.vh"

module tb_alu;

reg [31:0] a, b;
reg [3:0] alu_op;
wire [31:0] result;

integer i, op;
reg [31:0] x, y;

alu dut(.a(a), .b(b), .alu_op(alu_op), .result(result));

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
        $display("      inputs  : alu_op=%0d a=%h b=%h", alu_op, a, b);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

function [31:0] expected_out;
    input [3:0] op;
    input [31:0] x, y;
    reg signed [31:0] sx, sy;
    begin
        sx = x;
        sy = y;
        case (op)
            `ALU_ADD: expected_out = x + y;
            `ALU_SUB: expected_out = x - y;
            `ALU_CMP: expected_out = x - y;
            `ALU_MUL: expected_out = x * y;
            `ALU_DIV: if (y == 0) expected_out = 0; else expected_out = sx / sy;
            `ALU_MOD: if (y == 0) expected_out = 0; else expected_out = sx % sy;
            `ALU_LSL: expected_out = x << y[4:0];
            `ALU_LSR: expected_out = x >> y[4:0];
            `ALU_ASR: expected_out = sx >>> y[4:0];
            `ALU_OR:  expected_out = x | y;
            `ALU_AND: expected_out = x & y;
            `ALU_NOT: expected_out = ~y;
            `ALU_MOV: expected_out = y;
            default:  expected_out = 0;
        endcase
    end
endfunction

task run;
    input [3:0] o;
    input [31:0] x, y, exp;
    input [8*64-1:0] name;
    begin
        alu_op = o;
        a = x;
        b = y;
        #1;
        check(result, exp, name);
    end
endtask

initial begin
    $display("tb_alu");

    run(`ALU_ADD, 7, 5, 12, "add 7+5");
    run(`ALU_ADD, 32'hFFFFFFFF, 1, 0, "add wraps around");
    run(`ALU_ADD, 10, -3, 7, "add negative");
    run(`ALU_SUB, 5, 7, -2, "sub gives negative");
    run(`ALU_SUB, 32'h80000000, 1, 32'h7FFFFFFF, "sub overflow");
    run(`ALU_CMP, 9, 9, 0, "cmp result");

    run(`ALU_MUL, 12, 11, 132, "mul");
    run(`ALU_MUL, -4, 6, -24, "mul negative");
    run(`ALU_MUL, 32'h00010000, 32'h00010000, 0, "mul low 32 bits");

    run(`ALU_DIV, 100, 7, 14, "div");
    run(`ALU_DIV, -100, 7, -14, "div negative dividend");
    run(`ALU_DIV, 100, -7, -14, "div negative divisor");
    run(`ALU_DIV, 5, 0, 0, "div by zero");
    run(`ALU_MOD, 100, 7, 2, "mod");
    run(`ALU_MOD, -100, 7, -2, "mod negative");
    run(`ALU_MOD, 5, 0, 0, "mod by zero");

    run(`ALU_AND, 32'hF0F01234, 32'h0FF0FFFF, 32'h00F01234, "and");
    run(`ALU_OR, 32'hF0000000, 32'h0000000F, 32'hF000000F, "or");
    run(`ALU_NOT, 32'hDEADBEEF, 32'h0000FFFF, 32'hFFFF0000, "not");
    run(`ALU_MOV, 32'hDEADBEEF, 32'h12345678, 32'h12345678, "mov");

    run(`ALU_LSL, 1, 31, 32'h80000000, "lsl 31");
    run(`ALU_LSL, 3, 4, 32'h30, "lsl 4");
    run(`ALU_LSR, 32'h80000000, 31, 1, "lsr");
    run(`ALU_ASR, 32'h80000000, 4, 32'hF8000000, "asr negative");
    run(`ALU_ASR, 32'h40000000, 4, 32'h04000000, "asr positive");
    run(`ALU_LSL, 1, 33, 2, "shift only uses 5 bits");

    run(`ALU_NOP, 32'h1234, 32'h5678, 0, "nop");

    for (i = 0; i < 200; i = i + 1) begin
        for (op = 0; op < 14; op = op + 1) begin
            x = $random;
            y = $random;
            if (i % 10 == 0)
                y = {$random} % 41;
            run(op, x, y, expected_out(op, x, y), "random test");
        end
    end

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
