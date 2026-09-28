`timescale 1ns/1ps

module tb_instr_mem;

reg [31:0] addr;
wire [31:0] instr_out;
integer i;

instr_mem #(.DEPTH(64)) dut(
    .addr(addr),
    .instr_out(instr_out)
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
        $display("      inputs  : addr=%h", addr);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_instr_mem");

    for (i = 0; i < 64; i = i + 1)
        dut.mem[i] = 32'hA5A50000 + i;

    for (i = 0; i < 64; i = i + 1) begin
        addr = i * 4;
        #1;
        check(instr_out, 32'hA5A50000 + i, "read word at aligned address");
    end

    addr = 32'h13;
    #1;
    check(instr_out, 32'hA5A50004, "low 2 address bits ignored");

    dut.mem[5] = 32'h12345678;
    addr = 32'h14;
    #1;
    check(instr_out, 32'h12345678, "read is combinational");

    addr = 63 * 4;
    #1;
    check(instr_out, 32'hA5A5003F, "last word of memory");

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
