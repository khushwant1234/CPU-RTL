//=============================================================================
// tb_ex_mem_reg.sv  -  unit test for ex_mem_reg
// Checks reset to bubble and that every field is captured each cycle.
//=============================================================================
`timescale 1ns/1ps
module tb_ex_mem_reg;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0;
  logic [31:0] pc_in, alu_result_in, op2_in, pc_out, alu_result_out, op2_out;
  logic [3:0]  rd_addr_in, rd_addr_out;
  ctrl_t       ctrl_in, ctrl_out;

  ex_mem_reg dut (.*);

  always #5 clk = ~clk;

  initial begin
    $display("tb_ex_mem_reg");
    rst_n = 0;
    ctrl_in = CTRL_BUBBLE; ctrl_in.reg_write_en = 1; ctrl_in.alu_op = ALU_OR;
    pc_in = 32'h10; alu_result_in = 32'h20; op2_in = 32'h30; rd_addr_in = 4'd5;

    #1
    `CHECK_EQ(ctrl_out, CTRL_BUBBLE, "reset: ctrl is a bubble")
    `CHECK_EQ(alu_result_out, 32'h0, "reset: alu_result cleared")
    `CHECK_EQ(rd_addr_out, 4'h0, "reset: rd cleared")
    rst_n = 1;

    for (int i = 0; i < 8; i++) begin
      pc_in = 32'h1000 + 4 * i; alu_result_in = $urandom; op2_in = $urandom;
      rd_addr_in = i; ctrl_in.mem_write_en = i[0]; ctrl_in.mem_read_en = i[1];
      @(posedge clk); #1
      `CHECK_EQ(pc_out, pc_in, "pc captured")
      `CHECK_EQ(alu_result_out, alu_result_in, "alu_result captured")
      `CHECK_EQ(op2_out, op2_in, "op2 (store data) captured")
      `CHECK_EQ(rd_addr_out, rd_addr_in, "rd captured")
      `CHECK_EQ(ctrl_out, ctrl_in, "ctrl captured")
    end

    // output only changes on the edge
    alu_result_in = 32'hFFFF_FFFF;
    #2 `CHECK_TRUE(alu_result_out !== 32'hFFFF_FFFF, "no change between edges")

    `TB_FINISH
  end
endmodule
