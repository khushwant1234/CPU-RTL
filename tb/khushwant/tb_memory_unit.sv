//=============================================================================
// tb_memory_unit.sv  -  unit test for memory_unit
// Checks the data memory port for ld, st and a normal ALU instruction.
//=============================================================================
`timescale 1ns/1ps
module tb_memory_unit;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  ctrl_t       ctrl;
  logic [31:0] alu_result, op2, mem_addr, mem_wdata, mem_rdata, ld_result;
  logic        mem_we, mem_re;

  memory_unit dut (.*);

  initial begin
    $display("tb_memory_unit");

    // ld
    ctrl = CTRL_BUBBLE; ctrl.mem_read_en = 1; ctrl.mem_to_reg = 1; ctrl.reg_write_en = 1;
    alu_result = 32'h0000_0040; op2 = 32'h1111_1111; mem_rdata = 32'hCAFE_F00D;
    #1
    `CHECK_EQ(mem_addr,  32'h40, "ld: address = alu_result")
    `CHECK_EQ(mem_re,    1'b1,   "ld: read enable")
    `CHECK_EQ(mem_we,    1'b0,   "ld: no write")
    `CHECK_EQ(ld_result, 32'hCAFE_F00D, "ld: result = memory data")
    mem_rdata = 32'h0BAD_CAFE;
    #1 `CHECK_EQ(ld_result, 32'h0BAD_CAFE, "ld: result follows memory combinationally")

    // st
    ctrl = CTRL_BUBBLE; ctrl.mem_write_en = 1;
    alu_result = 32'h0000_0080; op2 = 32'h1234_5678;
    #1
    `CHECK_EQ(mem_addr,  32'h80, "st: address = alu_result")
    `CHECK_EQ(mem_wdata, 32'h1234_5678, "st: write data = op2")
    `CHECK_EQ(mem_we,    1'b1, "st: write enable")
    `CHECK_EQ(mem_re,    1'b0, "st: no read")

    // ALU op passes through without touching memory
    ctrl = CTRL_BUBBLE; ctrl.reg_write_en = 1; ctrl.alu_op = ALU_ADD;
    #1
    `CHECK_EQ(mem_we,    1'b0,  "add: no write")
    `CHECK_EQ(mem_re,    1'b0,  "add: no read")
    `CHECK_EQ(ld_result, 32'h0, "add: ld_result is 0")

    ctrl = CTRL_BUBBLE;
    #1 `CHECK_EQ(mem_we, 1'b0, "bubble: no write")

    `TB_FINISH
  end
endmodule
