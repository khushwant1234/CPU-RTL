`timescale 1ns/1ps
`include "defines.vh"

module tb_writeback;

reg [31:0] pc, alu_result, ld_result;
reg [3:0] rd_addr;
reg [`CTRL_W-1:0] ctrl;
wire [3:0] wb_addr;
wire [31:0] wb_data;
wire wb_en;

writeback dut(
    .pc(pc),
    .alu_result(alu_result),
    .ld_result(ld_result),
    .rd_addr(rd_addr),
    .ctrl(ctrl),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .wb_en(wb_en)
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
        $display("      inputs  : ctrl=%b pc=%h alu_result=%h ld_result=%h rd_addr=%0d", ctrl, pc, alu_result, ld_result, rd_addr);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_writeback");
    pc = 32'h100;
    alu_result = 32'hAAAAAAAA;
    ld_result = 32'h55555555;
    rd_addr = 3;

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_REG_WRITE] = 1;
    ctrl[`C_ALU_OP] = `ALU_ADD;
    #1;
    check(wb_data, 32'hAAAAAAAA, "alu data");
    check(wb_addr, 3, "alu rd");
    check(wb_en, 1, "alu write enable");

    ctrl[`C_MEM_TO_REG] = 1;
    ctrl[`C_MEM_READ] = 1;
    #1;
    check(wb_data, 32'h55555555, "ld data");
    check(wb_addr, 3, "ld rd");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_JUMP] = 1;
    ctrl[`C_IS_CALL] = 1;
    ctrl[`C_REG_WRITE] = 1;
    rd_addr = 0;
    #1;
    check(wb_data, 32'h104, "call data = pc + 4");
    check(wb_addr, `REG_RA, "call writes r15");
    check(wb_en, 1, "call write enable");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_MEM_WRITE] = 1;
    #1;
    check(wb_en, 0, "st no write");

    ctrl = `CTRL_BUBBLE;
    ctrl[`C_FLAGS_WRITE] = 1;
    ctrl[`C_ALU_OP] = `ALU_CMP;
    #1;
    check(wb_en, 0, "cmp no write");

    ctrl = `CTRL_BUBBLE;
    #1;
    check(wb_en, 0, "bubble no write");

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
