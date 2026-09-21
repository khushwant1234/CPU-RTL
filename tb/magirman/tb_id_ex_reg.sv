//=============================================================================
// tb_id_ex_reg.sv  -  unit test for id_ex_reg
// Checks: reset gives a bubble (alu_op = ALU_NOP), all fields captured,
// stall holds, flush inserts a bubble, flush has priority over stall.
//=============================================================================
`timescale 1ns/1ps
module tb_id_ex_reg;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic         rst_n;
  logic         clk = 0, stall = 0, flush = 0;
  logic [31:0]  pc_in, rs1_data_in, rs2_data_in, imm_ext_in;
  logic [26:0]  branch_offset_in;
  logic [3:0]   rd_addr_in, rs1_addr_in, rs2_addr_in;
  ctrl_t        ctrl_in;
  logic [31:0]  pc_out, rs1_data_out, rs2_data_out, imm_ext_out;
  logic [26:0]  branch_offset_out;
  logic [3:0]   rd_addr_out, rs1_addr_out, rs2_addr_out;
  ctrl_t        ctrl_out;

  id_ex_reg dut (.*);

  always #5 clk = ~clk;

  ctrl_t bubble, live;

  task automatic drive(input logic [31:0] base);
    pc_in            = base;
    rs1_data_in      = base + 1;
    rs2_data_in      = base + 2;
    imm_ext_in       = base + 3;
    branch_offset_in = base[26:0] + 4;
    rd_addr_in       = base[3:0] + 1;
    rs1_addr_in      = base[3:0] + 2;
    rs2_addr_in      = base[3:0] + 3;
  endtask

  task automatic check_all(input logic [31:0] base, input ctrl_t c, input string what);
    `CHECK_EQ(pc_out,            base,             {what, ": pc"})
    `CHECK_EQ(rs1_data_out,      base + 1,         {what, ": rs1_data"})
    `CHECK_EQ(rs2_data_out,      base + 2,         {what, ": rs2_data"})
    `CHECK_EQ(imm_ext_out,       base + 3,         {what, ": imm_ext"})
    `CHECK_EQ(branch_offset_out, base[26:0] + 4,   {what, ": branch_offset"})
    `CHECK_EQ(rd_addr_out,       4'(base[3:0] + 1), {what, ": rd_addr"})
    `CHECK_EQ(rs1_addr_out,      4'(base[3:0] + 2), {what, ": rs1_addr"})
    `CHECK_EQ(rs2_addr_out,      4'(base[3:0] + 3), {what, ": rs2_addr"})
    `CHECK_EQ(ctrl_out,          c,                {what, ": ctrl"})
  endtask

  task automatic check_bubble(input string what);
    `CHECK_EQ(ctrl_out, bubble, {what, ": ctrl is a bubble"})
    `CHECK_EQ(ctrl_out.alu_op, ALU_NOP, {what, ": alu_op is ALU_NOP, not ALU_ADD"})
    `CHECK_EQ(ctrl_out.reg_write_en, 1'b0, {what, ": no reg write"})
    `CHECK_EQ(ctrl_out.mem_write_en, 1'b0, {what, ": no mem write"})
    `CHECK_EQ(rd_addr_out, 4'd0, {what, ": rd cleared"})
  endtask

  initial begin
    $display("tb_id_ex_reg");
    rst_n = 0;
    bubble = '0; bubble.alu_op = ALU_NOP;
    live   = '0; live.reg_write_en = 1; live.rs1_valid = 1; live.rs2_valid = 1;
    live.mem_write_en = 1; live.alu_op = ALU_SUB;

    drive(32'h100); ctrl_in = live;
    #1 check_bubble("during reset");
    @(posedge clk); #1 check_bubble("reset held over a clock edge");
    rst_n = 1;

    @(posedge clk); #1 check_all(32'h100, live, "capture");

    drive(32'h200);
    @(posedge clk); #1 check_all(32'h200, live, "capture next");

    // stall holds everything
    stall = 1; drive(32'h300);
    @(posedge clk); #1 check_all(32'h200, live, "stall holds");
    stall = 0;
    @(posedge clk); #1 check_all(32'h300, live, "released after stall");

    // flush -> bubble
    flush = 1; drive(32'h400);
    @(posedge clk); #1 check_bubble("flush");
    flush = 0;

    // flush beats stall
    @(posedge clk); #1 check_all(32'h400, live, "capture after flush");
    stall = 1; flush = 1;
    @(posedge clk); #1 check_bubble("flush + stall");
    stall = 0; flush = 0;

    `TB_FINISH
  end
endmodule
