`timescale 1ns/1ps
`include "defines.vh"

module tb_if_id_reg;

reg clk = 0;
reg rst_n;
reg stall = 0, flush = 0;
reg [31:0] pc_in = 0, instr_in = 0;
wire [31:0] pc_out, instr_out;

if_id_reg dut(
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .pc_in(pc_in),
    .instr_in(instr_in),
    .pc_out(pc_out),
    .instr_out(instr_out)
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
        $display("      inputs  : rst_n=%b stall=%b flush=%b pc_in=%h instr_in=%h", rst_n, stall, flush, pc_in, instr_in);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

task tick;
    input [31:0] pc;
    input [31:0] instr;
    begin
        pc_in = pc;
        instr_in = instr;
        @(posedge clk);
        #1;
    end
endtask

initial begin
    $display("tb_if_id_reg");
    rst_n = 0;

    #1;
    check(instr_out, `NOP_INSTR, "reset loads nop instruction");
    check(pc_out, 0, "reset clears pc");
    check(instr_out == 0, 0, "reset value is not all zeros");
    rst_n = 1;

    tick(32'h4, 32'h11111111);
    check(pc_out, 32'h4, "pc captured");
    check(instr_out, 32'h11111111, "instruction captured");

    tick(32'h8, 32'h22222222);
    check(instr_out, 32'h22222222, "next instruction captured");

    stall = 1;
    tick(32'hC, 32'h33333333);
    check(pc_out, 32'h8, "stall holds pc");
    check(instr_out, 32'h22222222, "stall holds instruction");
    tick(32'h10, 32'h44444444);
    check(instr_out, 32'h22222222, "stall holds for many cycles");
    stall = 0;

    flush = 1;
    tick(32'h40, 32'h55555555);
    check(instr_out, `NOP_INSTR, "flush puts nop");
    check(pc_out, 32'h40, "flush still passes pc");
    flush = 0;

    stall = 1;
    flush = 1;
    tick(32'h44, 32'h66666666);
    check(instr_out, `NOP_INSTR, "flush has priority over stall");
    stall = 0;
    flush = 0;

    tick(32'h48, 32'h77777777);
    check(instr_out, 32'h77777777, "normal operation again");

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
