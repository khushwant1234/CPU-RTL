`timescale 1ns/1ps

module tb_flags;

reg clk = 0;
reg rst_n;
reg write_en = 0;
reg [31:0] a = 0, b = 0;
wire flag_e, flag_gt;

flags dut(
    .clk(clk),
    .rst_n(rst_n),
    .write_en(write_en),
    .a(a),
    .b(b),
    .flag_e(flag_e),
    .flag_gt(flag_gt)
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
        $display("      inputs  : rst_n=%b write_en=%b a=%h b=%h", rst_n, write_en, a, b);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

task do_cmp;
    input [31:0] x, y;
    input exp_e, exp_gt;
    input [8*64-1:0] name;
    begin
        a = x;
        b = y;
        write_en = 1;
        @(posedge clk);
        #1;
        write_en = 0;
        check({flag_e, flag_gt}, {exp_e, exp_gt}, name);
    end
endtask

initial begin
    $display("tb_flags");
    rst_n = 0;
    #1;
    check({flag_e, flag_gt}, 2'b00, "reset");
    rst_n = 1;

    do_cmp(5, 5, 1, 0, "5 == 5");
    do_cmp(9, 5, 0, 1, "9 > 5");
    do_cmp(2, 5, 0, 0, "2 < 5");
    do_cmp(-1, 1, 0, 0, "-1 < 1");
    do_cmp(1, -1, 0, 1, "1 > -1");
    do_cmp(32'h7FFFFFFF, 32'h80000000, 0, 1, "max > min");
    do_cmp(-7, -7, 1, 0, "-7 == -7");

    a = 100;
    b = 1;
    repeat (3) @(posedge clk);
    #1;
    check({flag_e, flag_gt}, 2'b10, "hold when write_en = 0");

    do_cmp(50, 10, 0, 1, "set GT");
    a = 4;
    b = 4;
    write_en = 1;
    #2;
    check({flag_e, flag_gt}, 2'b01, "no change before clock");
    @(posedge clk);
    #1;
    check({flag_e, flag_gt}, 2'b10, "change after clock");
    write_en = 0;

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
