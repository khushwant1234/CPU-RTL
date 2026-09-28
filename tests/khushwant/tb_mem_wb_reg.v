`timescale 1ns/1ps
`include "defines.vh"

module tb_mem_wb_reg;

reg clk = 0;
reg rst_n;
reg [31:0] pc_in, alu_result_in, ld_result_in;
reg [3:0] rd_addr_in;
reg [`CTRL_W-1:0] ctrl_in;
wire [31:0] pc_out, alu_result_out, ld_result_out;
wire [3:0] rd_addr_out;
wire [`CTRL_W-1:0] ctrl_out;

integer i;

mem_wb_reg dut(
    .clk(clk),
    .rst_n(rst_n),
    .pc_in(pc_in),
    .alu_result_in(alu_result_in),
    .ld_result_in(ld_result_in),
    .rd_addr_in(rd_addr_in),
    .ctrl_in(ctrl_in),
    .pc_out(pc_out),
    .alu_result_out(alu_result_out),
    .ld_result_out(ld_result_out),
    .rd_addr_out(rd_addr_out),
    .ctrl_out(ctrl_out)
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
        $display("      inputs  : rst_n=%b pc_in=%h alu_result_in=%h ld_result_in=%h rd_addr_in=%0d ctrl_in=%b", rst_n, pc_in, alu_result_in, ld_result_in, rd_addr_in, ctrl_in);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_mem_wb_reg");
    rst_n = 0;
    ctrl_in = `CTRL_BUBBLE;
    ctrl_in[`C_REG_WRITE] = 1;
    ctrl_in[`C_MEM_TO_REG] = 1;
    pc_in = 32'h10;
    alu_result_in = 32'h20;
    ld_result_in = 32'h30;
    rd_addr_in = 5;

    #1;
    check(ctrl_out, `CTRL_BUBBLE, "reset ctrl");
    check(ctrl_out[`C_REG_WRITE], 0, "reset reg_write");
    check(ld_result_out, 0, "reset ld_result");
    rst_n = 1;

    for (i = 0; i < 8; i = i + 1) begin
        pc_in = 32'h2000 + 4*i;
        alu_result_in = $random;
        ld_result_in = $random;
        rd_addr_in = 15 - i;
        ctrl_in[`C_IS_CALL] = i[0];
        @(posedge clk);
        #1;
        check(pc_out, pc_in, "pc");
        check(alu_result_out, alu_result_in, "alu_result");
        check(ld_result_out, ld_result_in, "ld_result");
        check(rd_addr_out, rd_addr_in, "rd");
        check(ctrl_out, ctrl_in, "ctrl");
    end

    rst_n = 0;
    #1;
    check(ctrl_out, `CTRL_BUBBLE, "async reset");

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
