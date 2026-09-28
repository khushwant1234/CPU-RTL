`timescale 1ns/1ps

module tb_reg_file;

reg clk = 0;
reg rst_n;
reg rd_write_en = 0;
reg [3:0] rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
reg [31:0] rd_data = 0;
wire [31:0] rs1_data, rs2_data;
integer r;

reg_file dut(
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .rd_write_en(rd_write_en),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
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
        $display("      inputs  : rst_n=%b rd_write_en=%b rd_addr=%0d rd_data=%h rs1_addr=%0d rs2_addr=%0d", rst_n, rd_write_en, rd_addr, rd_data, rs1_addr, rs2_addr);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

task write_reg;
    input [3:0] rr;
    input [31:0] v;
    begin
        rd_addr = rr;
        rd_data = v;
        rd_write_en = 1;
        @(posedge clk);
        #1;
        rd_write_en = 0;
    end
endtask

initial begin
    $display("tb_reg_file");
    rst_n = 0;

    #1;
    for (r = 0; r < 16; r = r + 1) begin
        rs1_addr = r;
        rs2_addr = r;
        #1;
        check(rs1_data, 0, "reset clears register (port 1)");
        check(rs2_data, 0, "reset clears register (port 2)");
    end
    rst_n = 1;

    for (r = 0; r < 16; r = r + 1)
        write_reg(r, 32'hC0DE0000 + r * 32'h11);

    for (r = 0; r < 16; r = r + 1) begin
        rs1_addr = r;
        rs2_addr = 15 - r;
        #1;
        check(rs1_data, 32'hC0DE0000 + r * 32'h11, "read back on port 1");
        check(rs2_data, 32'hC0DE0000 + (15 - r) * 32'h11, "read back on port 2");
    end

    rs1_addr = 0;
    #1;
    check(rs1_data, 32'hC0DE0000, "r0 is a normal register");

    rd_addr = 3;
    rd_data = 32'hFFFFFFFF;
    rd_write_en = 0;
    @(posedge clk);
    #1;
    rs1_addr = 3;
    #1;
    check(rs1_data, 32'hC0DE0033, "no write when write enable is 0");

    rd_addr = 7;
    rd_data = 32'h12345678;
    rd_write_en = 1;
    rs1_addr = 7;
    rs2_addr = 7;
    #1;
    check(rs1_data, 32'h12345678, "bypass on port 1 before clock edge");
    check(rs2_data, 32'h12345678, "bypass on port 2 before clock edge");
    rs2_addr = 8;
    #1;
    check(rs2_data, 32'hC0DE0088, "no bypass for other register");
    @(posedge clk);
    #1;
    rd_write_en = 0;
    #1;
    check(rs1_data, 32'h12345678, "value stored after clock edge");

    write_reg(14, 32'h00000FFC);
    write_reg(15, 32'h00000020);
    rs1_addr = 14;
    rs2_addr = 15;
    #1;
    check(rs1_data, 32'h00000FFC, "sp (r14) read");
    check(rs2_data, 32'h00000020, "ra (r15) read");

    rst_n = 0;
    #1;
    check(rs1_data, 0, "async reset clears registers");
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
