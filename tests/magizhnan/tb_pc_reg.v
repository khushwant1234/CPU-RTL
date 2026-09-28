`timescale 1ns/1ps

module tb_pc_reg;

reg clk = 0;
reg rst_n;
reg stall = 0;
reg [31:0] pc_next = 0;
wire [31:0] pc_out;
integer i;

pc_reg dut(
    .clk(clk),
    .rst_n(rst_n),
    .pc_next(pc_next),
    .stall(stall),
    .pc_out(pc_out)
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
        $display("      inputs  : rst_n=%b stall=%b pc_next=%h", rst_n, stall, pc_next);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_pc_reg");
    rst_n = 0;

    pc_next = 32'hDEADBEEF;
    #1;
    check(pc_out, 0, "pc is 0 during reset");
    @(posedge clk);
    #1;
    check(pc_out, 0, "reset wins over pc_next at clock edge");
    rst_n = 1;

    for (i = 1; i <= 4; i = i + 1) begin
        pc_next = i * 4;
        @(posedge clk);
        #1;
        check(pc_out, i * 4, "pc follows pc_next");
    end

    stall = 1;
    pc_next = 32'h100;
    repeat (3) begin
        @(posedge clk);
        #1;
        check(pc_out, 32'h10, "pc holds while stalled");
    end
    stall = 0;
    @(posedge clk);
    #1;
    check(pc_out, 32'h100, "pc updates after stall goes low");

    pc_next = 32'h400;
    @(posedge clk);
    #1;
    check(pc_out, 32'h400, "pc jumps to branch target");

    #2;
    rst_n = 0;
    #1;
    check(pc_out, 0, "async reset without clock edge");
    rst_n = 1;

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
