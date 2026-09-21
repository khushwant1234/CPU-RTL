//=============================================================================
// tb_if_id_reg.sv  -  unit test for if_id_reg
// Checks: reset loads NOP_INSTR (not all zeros), normal capture, stall hold,
// flush inserts NOP while pc still advances, flush has priority over stall.
//=============================================================================
`timescale 1ns/1ps
module tb_if_id_reg;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0, stall = 0, flush = 0;
  logic [31:0] pc_in = 0, instr_in = 0, pc_out, instr_out;

  if_id_reg dut (.*);

  always #5 clk = ~clk;

  task automatic tick(input logic [31:0] pc, input logic [31:0] instr);
    pc_in = pc; instr_in = instr;
    @(posedge clk); #1;
  endtask

  initial begin
    $display("tb_if_id_reg");
    rst_n = 0;

    #1
    `CHECK_EQ(instr_out, NOP_INSTR, "reset loads NOP_INSTR")
    `CHECK_EQ(pc_out,    32'h0,     "reset clears pc")
    `CHECK_TRUE(instr_out !== 32'h0, "reset value is not all-zero (add r0,r0,r0)")
    rst_n = 1;

    tick(32'h4, 32'h1111_1111);
    `CHECK_EQ(pc_out,    32'h4,         "captures pc")
    `CHECK_EQ(instr_out, 32'h1111_1111, "captures instruction")

    tick(32'h8, 32'h2222_2222);
    `CHECK_EQ(instr_out, 32'h2222_2222, "captures next instruction")

    // stall: hold both fields
    stall = 1;
    tick(32'hC, 32'h3333_3333);
    `CHECK_EQ(pc_out,    32'h8,         "stall holds pc")
    `CHECK_EQ(instr_out, 32'h2222_2222, "stall holds instruction")
    tick(32'h10, 32'h4444_4444);
    `CHECK_EQ(instr_out, 32'h2222_2222, "stall holds for multiple cycles")
    stall = 0;

    // flush: instruction becomes NOP, pc still passes through
    flush = 1;
    tick(32'h40, 32'h5555_5555);
    `CHECK_EQ(instr_out, NOP_INSTR, "flush inserts NOP")
    `CHECK_EQ(pc_out,    32'h40,    "flush still passes pc")
    flush = 0;

    // flush wins over stall
    stall = 1; flush = 1;
    tick(32'h44, 32'h6666_6666);
    `CHECK_EQ(instr_out, NOP_INSTR, "flush has priority over stall")
    stall = 0; flush = 0;

    tick(32'h48, 32'h7777_7777);
    `CHECK_EQ(instr_out, 32'h7777_7777, "normal operation resumes")

    `TB_FINISH
  end
endmodule
