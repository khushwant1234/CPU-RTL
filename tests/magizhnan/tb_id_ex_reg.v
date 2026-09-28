`timescale 1ns/1ps
`include "defines.vh"

module tb_id_ex_reg;

reg clk = 0;
reg rst_n;
reg stall = 0, flush = 0;
reg [31:0] pc_in, rs1_data_in, rs2_data_in, imm_ext_in;
reg [26:0] branch_offset_in;
reg [3:0] rd_addr_in, rs1_addr_in, rs2_addr_in;
reg [`CTRL_W-1:0] ctrl_in;
wire [31:0] pc_out, rs1_data_out, rs2_data_out, imm_ext_out;
wire [26:0] branch_offset_out;
wire [3:0] rd_addr_out, rs1_addr_out, rs2_addr_out;
wire [`CTRL_W-1:0] ctrl_out;

reg [`CTRL_W-1:0] live;

id_ex_reg dut(
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .pc_in(pc_in),
    .rs1_data_in(rs1_data_in),
    .rs2_data_in(rs2_data_in),
    .imm_ext_in(imm_ext_in),
    .branch_offset_in(branch_offset_in),
    .rd_addr_in(rd_addr_in),
    .rs1_addr_in(rs1_addr_in),
    .rs2_addr_in(rs2_addr_in),
    .ctrl_in(ctrl_in),
    .pc_out(pc_out),
    .rs1_data_out(rs1_data_out),
    .rs2_data_out(rs2_data_out),
    .imm_ext_out(imm_ext_out),
    .branch_offset_out(branch_offset_out),
    .rd_addr_out(rd_addr_out),
    .rs1_addr_out(rs1_addr_out),
    .rs2_addr_out(rs2_addr_out),
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
        $display("      inputs  : rst_n=%b stall=%b flush=%b pc_in=%h rs1_data_in=%h rs2_data_in=%h imm_ext_in=%h branch_offset_in=%h rd_addr_in=%0d rs1_addr_in=%0d rs2_addr_in=%0d ctrl_in=%b", rst_n, stall, flush, pc_in, rs1_data_in, rs2_data_in, imm_ext_in, branch_offset_in, rd_addr_in, rs1_addr_in, rs2_addr_in, ctrl_in);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

task drive;
    input [31:0] base;
    begin
        pc_in = base;
        rs1_data_in = base + 1;
        rs2_data_in = base + 2;
        imm_ext_in = base + 3;
        branch_offset_in = base[26:0] + 4;
        rd_addr_in = base[3:0] + 1;
        rs1_addr_in = base[3:0] + 2;
        rs2_addr_in = base[3:0] + 3;
    end
endtask

task check_all;
    input [31:0] base;
    input [`CTRL_W-1:0] c;
    reg [26:0] off;
    reg [3:0] rd, r1, r2;
    begin
        off = base[26:0] + 4;
        rd = base[3:0] + 1;
        r1 = base[3:0] + 2;
        r2 = base[3:0] + 3;
        check(pc_out, base, "pc");
        check(rs1_data_out, base + 1, "rs1_data");
        check(rs2_data_out, base + 2, "rs2_data");
        check(imm_ext_out, base + 3, "imm_ext");
        check(branch_offset_out, off, "branch_offset");
        check(rd_addr_out, rd, "rd_addr");
        check(rs1_addr_out, r1, "rs1_addr");
        check(rs2_addr_out, r2, "rs2_addr");
        check(ctrl_out, c, "ctrl");
    end
endtask

task check_bubble;
    begin
        check(ctrl_out, `CTRL_BUBBLE, "ctrl is bubble");
        check(ctrl_out[`C_ALU_OP], `ALU_NOP, "alu_op is nop not add");
        check(ctrl_out[`C_REG_WRITE], 0, "no reg write");
        check(ctrl_out[`C_MEM_WRITE], 0, "no mem write");
        check(rd_addr_out, 0, "rd cleared");
    end
endtask

initial begin
    $display("tb_id_ex_reg");
    rst_n = 0;
    live = `CTRL_BUBBLE;
    live[`C_REG_WRITE] = 1;
    live[`C_RS1_VALID] = 1;
    live[`C_RS2_VALID] = 1;
    live[`C_MEM_WRITE] = 1;
    live[`C_ALU_OP] = `ALU_SUB;

    drive(32'h100);
    ctrl_in = live;
    #1;
    check_bubble;
    @(posedge clk);
    #1;
    check_bubble;
    rst_n = 1;

    @(posedge clk);
    #1;
    check_all(32'h100, live);

    drive(32'h200);
    @(posedge clk);
    #1;
    check_all(32'h200, live);

    stall = 1;
    drive(32'h300);
    @(posedge clk);
    #1;
    check_all(32'h200, live);
    stall = 0;
    @(posedge clk);
    #1;
    check_all(32'h300, live);

    flush = 1;
    drive(32'h400);
    @(posedge clk);
    #1;
    check_bubble;
    flush = 0;

    @(posedge clk);
    #1;
    check_all(32'h400, live);
    stall = 1;
    flush = 1;
    @(posedge clk);
    #1;
    check_bubble;
    stall = 0;
    flush = 0;

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
