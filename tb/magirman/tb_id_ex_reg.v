//=============================================================================
// tb_id_ex_reg.v  -  unit test for id_ex_reg
// Checks: reset gives a bubble (alu_op = ALU_NOP), all fields captured,
// stall holds, flush inserts a bubble, flush has priority over stall.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_id_ex_reg;
  `TB_INIT

  reg                clk = 0;
  reg                rst_n;
  reg                stall = 0, flush = 0;
  reg  [31:0]        pc_in, rs1_data_in, rs2_data_in, imm_ext_in;
  reg  [26:0]        branch_offset_in;
  reg  [3:0]         rd_addr_in, rs1_addr_in, rs2_addr_in;
  reg  [`CTRL_W-1:0] ctrl_in;
  wire [31:0]        pc_out, rs1_data_out, rs2_data_out, imm_ext_out;
  wire [26:0]        branch_offset_out;
  wire [3:0]         rd_addr_out, rs1_addr_out, rs2_addr_out;
  wire [`CTRL_W-1:0] ctrl_out;

  id_ex_reg dut (
    .clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush),
    .pc_in(pc_in), .rs1_data_in(rs1_data_in), .rs2_data_in(rs2_data_in),
    .imm_ext_in(imm_ext_in), .branch_offset_in(branch_offset_in),
    .rd_addr_in(rd_addr_in), .rs1_addr_in(rs1_addr_in), .rs2_addr_in(rs2_addr_in),
    .ctrl_in(ctrl_in),
    .pc_out(pc_out), .rs1_data_out(rs1_data_out), .rs2_data_out(rs2_data_out),
    .imm_ext_out(imm_ext_out), .branch_offset_out(branch_offset_out),
    .rd_addr_out(rd_addr_out), .rs1_addr_out(rs1_addr_out), .rs2_addr_out(rs2_addr_out),
    .ctrl_out(ctrl_out)
  );

  always #5 clk = ~clk;

  reg [`CTRL_W-1:0] live;

  // every field gets a value derived from base so a mix-up shows up
  task drive;
    input [31:0] base;
    begin
      pc_in            = base;
      rs1_data_in      = base + 1;
      rs2_data_in      = base + 2;
      imm_ext_in       = base + 3;
      branch_offset_in = base[26:0] + 27'd4;
      rd_addr_in       = base[3:0] + 4'd1;
      rs1_addr_in      = base[3:0] + 4'd2;
      rs2_addr_in      = base[3:0] + 4'd3;
    end
  endtask

  task check_all;
    input [31:0]        base;
    input [`CTRL_W-1:0] c;
    begin
      `CHECK_EQ(pc_out,            base,               "pc")
      `CHECK_EQ(rs1_data_out,      base + 1,           "rs1_data")
      `CHECK_EQ(rs2_data_out,      base + 2,           "rs2_data")
      `CHECK_EQ(imm_ext_out,       base + 3,           "imm_ext")
      `CHECK_EQ(branch_offset_out, base[26:0] + 27'd4, "branch_offset")
      `CHECK_EQ(rd_addr_out,       base[3:0] + 4'd1,   "rd_addr")
      `CHECK_EQ(rs1_addr_out,      base[3:0] + 4'd2,   "rs1_addr")
      `CHECK_EQ(rs2_addr_out,      base[3:0] + 4'd3,   "rs2_addr")
      `CHECK_EQ(ctrl_out,          c,                  "ctrl")
    end
  endtask

  task check_bubble;
    begin
      `CHECK_EQ(ctrl_out, `CTRL_BUBBLE, "ctrl is a bubble")
      `CHECK_EQ(ctrl_out[`C_ALU_OP], `ALU_NOP, "alu_op is ALU_NOP, not ALU_ADD")
      `CHECK_EQ(ctrl_out[`C_REG_WRITE], 1'b0, "no reg write")
      `CHECK_EQ(ctrl_out[`C_MEM_WRITE], 1'b0, "no mem write")
      `CHECK_EQ(rd_addr_out, 4'd0, "rd cleared")
    end
  endtask

  initial begin
    $display("tb_id_ex_reg");
    rst_n = 0;
    live = `CTRL_BUBBLE;
    live[`C_REG_WRITE] = 1; live[`C_RS1_VALID] = 1; live[`C_RS2_VALID] = 1;
    live[`C_MEM_WRITE] = 1; live[`C_ALU_OP] = `ALU_SUB;

    drive(32'h100); ctrl_in = live;
    #1 check_bubble;                       // during reset
    @(posedge clk); #1 check_bubble;       // reset held over a clock edge
    rst_n = 1;

    @(posedge clk); #1 check_all(32'h100, live);

    drive(32'h200);
    @(posedge clk); #1 check_all(32'h200, live);

    // stall holds everything
    stall = 1; drive(32'h300);
    @(posedge clk); #1 check_all(32'h200, live);
    stall = 0;
    @(posedge clk); #1 check_all(32'h300, live);

    // flush -> bubble
    flush = 1; drive(32'h400);
    @(posedge clk); #1 check_bubble;
    flush = 0;

    // flush beats stall
    @(posedge clk); #1 check_all(32'h400, live);
    stall = 1; flush = 1;
    @(posedge clk); #1 check_bubble;
    stall = 0; flush = 0;

    `TB_FINISH
  end
endmodule
