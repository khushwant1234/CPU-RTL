//=============================================================================
// tb_mem_wb_reg.v  -  unit test for mem_wb_reg
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_mem_wb_reg;
  `TB_INIT

  reg                clk = 0;
  reg                rst_n;
  reg  [31:0]        pc_in, alu_result_in, ld_result_in;
  reg  [3:0]         rd_addr_in;
  reg  [`CTRL_W-1:0] ctrl_in;
  wire [31:0]        pc_out, alu_result_out, ld_result_out;
  wire [3:0]         rd_addr_out;
  wire [`CTRL_W-1:0] ctrl_out;
  integer            i;

  mem_wb_reg dut (
    .clk(clk), .rst_n(rst_n),
    .pc_in(pc_in), .alu_result_in(alu_result_in), .ld_result_in(ld_result_in),
    .rd_addr_in(rd_addr_in), .ctrl_in(ctrl_in),
    .pc_out(pc_out), .alu_result_out(alu_result_out), .ld_result_out(ld_result_out),
    .rd_addr_out(rd_addr_out), .ctrl_out(ctrl_out)
  );

  always #5 clk = ~clk;

  initial begin
    $display("tb_mem_wb_reg");
    rst_n = 0;
    ctrl_in = `CTRL_BUBBLE; ctrl_in[`C_REG_WRITE] = 1; ctrl_in[`C_MEM_TO_REG] = 1;
    pc_in = 32'h10; alu_result_in = 32'h20; ld_result_in = 32'h30; rd_addr_in = 4'd5;

    #1
    `CHECK_EQ(ctrl_out, `CTRL_BUBBLE, "reset: ctrl is a bubble")
    `CHECK_EQ(ctrl_out[`C_REG_WRITE], 1'b0, "reset: no register write")
    `CHECK_EQ(ld_result_out, 32'h0, "reset: ld_result cleared")
    rst_n = 1;

    for (i = 0; i < 8; i = i + 1) begin
      pc_in = 32'h2000 + 4 * i; alu_result_in = $random; ld_result_in = $random;
      rd_addr_in = 15 - i; ctrl_in[`C_IS_CALL] = i[0];
      @(posedge clk); #1
      `CHECK_EQ_I(pc_out, pc_in, "pc captured", i)
      `CHECK_EQ_I(alu_result_out, alu_result_in, "alu_result captured", i)
      `CHECK_EQ_I(ld_result_out, ld_result_in, "ld_result captured", i)
      `CHECK_EQ_I(rd_addr_out, rd_addr_in, "rd captured", i)
      `CHECK_EQ_I(ctrl_out, ctrl_in, "ctrl captured", i)
    end

    rst_n = 0;
    #1 `CHECK_EQ(ctrl_out, `CTRL_BUBBLE, "async reset back to bubble")

    `TB_FINISH
  end
endmodule
