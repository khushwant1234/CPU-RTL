`timescale 1ns/1ps
`include "defines.vh"

module tb_memory_unit;

reg [`CTRL_W-1:0] ctrl;
reg [31:0] alu_result, op2, mem_rdata;
wire [31:0] mem_addr, mem_wdata, ld_result;
wire mem_we, mem_re;

memory_unit dut(
    .ctrl(ctrl),
    .alu_result(alu_result),
    .op2(op2),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_re(mem_re),
    .mem_rdata(mem_rdata),
    .ld_result(ld_result)
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
        $display("      inputs  : ctrl=%b alu_result=%h op2=%h mem_rdata=%h", ctrl, alu_result, op2, mem_rdata);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_memory_unit");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_MEM_READ] = 1;
    ctrl[`C_MEM_TO_REG] = 1;
    ctrl[`C_REG_WRITE] = 1;
    alu_result = 32'h40;
    op2 = 32'h11111111;
    mem_rdata = 32'hCAFEF00D;
    #1;
    check(mem_addr, 32'h40, "ld address");
    check(mem_re, 1, "ld read enable");
    check(mem_we, 0, "ld write enable");
    check(ld_result, 32'hCAFEF00D, "ld result");
    mem_rdata = 32'h0BADCAFE;
    #1;
    check(ld_result, 32'h0BADCAFE, "ld result changes with memory");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_MEM_WRITE] = 1;
    alu_result = 32'h80;
    op2 = 32'h12345678;
    #1;
    check(mem_addr, 32'h80, "st address");
    check(mem_wdata, 32'h12345678, "st data");
    check(mem_we, 1, "st write enable");
    check(mem_re, 0, "st read enable");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_REG_WRITE] = 1;
    ctrl[`C_ALU_OP] = `ALU_ADD;
    #1;
    check(mem_we, 0, "add write enable");
    check(mem_re, 0, "add read enable");
    check(ld_result, 0, "add ld_result");

    ctrl = `CTRL_BUBBLE;
    #1;
    check(mem_we, 0, "bubble write enable");

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
