//=============================================================================
// tb_mem_wb_reg.sv  -  unit test for mem_wb_reg
//=============================================================================
`timescale 1ns/1ps
module tb_mem_wb_reg;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0;
  logic [31:0] pc_in, alu_result_in, ld_result_in, pc_out, alu_result_out, ld_result_out;
  logic [3:0]  rd_addr_in, rd_addr_out;
  ctrl_t       ctrl_in, ctrl_out;

  mem_wb_reg dut (.*);

  always #5 clk = ~clk;

  initial begin
    $display("tb_mem_wb_reg");
    rst_n = 0;
    ctrl_in = CTRL_BUBBLE; ctrl_in.reg_write_en = 1; ctrl_in.mem_to_reg = 1;
    pc_in = 32'h10; alu_result_in = 32'h20; ld_result_in = 32'h30; rd_addr_in = 4'd5;

    #1
    `CHECK_EQ(ctrl_out, CTRL_BUBBLE, "reset: ctrl is a bubble")
    `CHECK_EQ(ctrl_out.reg_write_en, 1'b0, "reset: no register write")
    `CHECK_EQ(ld_result_out, 32'h0, "reset: ld_result cleared")
    rst_n = 1;

    for (int i = 0; i < 8; i++) begin
      pc_in = 32'h2000 + 4 * i; alu_result_in = $urandom; ld_result_in = $urandom;
      rd_addr_in = 15 - i; ctrl_in.is_call = i[0];
      @(posedge clk); #1
      `CHECK_EQ(pc_out, pc_in, "pc captured")
      `CHECK_EQ(alu_result_out, alu_result_in, "alu_result captured")
      `CHECK_EQ(ld_result_out, ld_result_in, "ld_result captured")
      `CHECK_EQ(rd_addr_out, rd_addr_in, "rd captured")
      `CHECK_EQ(ctrl_out, ctrl_in, "ctrl captured")
    end

    rst_n = 0;
    #1 `CHECK_EQ(ctrl_out, CTRL_BUBBLE, "async reset back to bubble")

    `TB_FINISH
  end
endmodule
