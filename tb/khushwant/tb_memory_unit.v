//=============================================================================
// tb_memory_unit.v  -  unit test for memory_unit
// Checks the data memory port for ld, st and a normal ALU instruction.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_memory_unit;
  `TB_INIT

  reg  [`CTRL_W-1:0] ctrl;
  reg  [31:0]        alu_result, op2, mem_rdata;
  wire [31:0]        mem_addr, mem_wdata, ld_result;
  wire               mem_we, mem_re;

  memory_unit dut (
    .ctrl(ctrl), .alu_result(alu_result), .op2(op2),
    .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we), .mem_re(mem_re),
    .mem_rdata(mem_rdata), .ld_result(ld_result)
  );

  initial begin
    $display("tb_memory_unit");

    // ld
    ctrl = `CTRL_BUBBLE; ctrl[`C_MEM_READ] = 1; ctrl[`C_MEM_TO_REG] = 1; ctrl[`C_REG_WRITE] = 1;
    alu_result = 32'h0000_0040; op2 = 32'h1111_1111; mem_rdata = 32'hCAFE_F00D;
    #1
    `CHECK_EQ(mem_addr,  32'h40, "ld: address = alu_result")
    `CHECK_EQ(mem_re,    1'b1,   "ld: read enable")
    `CHECK_EQ(mem_we,    1'b0,   "ld: no write")
    `CHECK_EQ(ld_result, 32'hCAFE_F00D, "ld: result = memory data")
    mem_rdata = 32'h0BAD_CAFE;
    #1 `CHECK_EQ(ld_result, 32'h0BAD_CAFE, "ld: result follows memory combinationally")

    // st
    ctrl = `CTRL_BUBBLE; ctrl[`C_MEM_WRITE] = 1;
    alu_result = 32'h0000_0080; op2 = 32'h1234_5678;
    #1
    `CHECK_EQ(mem_addr,  32'h80, "st: address = alu_result")
    `CHECK_EQ(mem_wdata, 32'h1234_5678, "st: write data = op2")
    `CHECK_EQ(mem_we,    1'b1, "st: write enable")
    `CHECK_EQ(mem_re,    1'b0, "st: no read")

    // ALU op passes through without touching memory
    ctrl = `CTRL_BUBBLE; ctrl[`C_REG_WRITE] = 1; ctrl[`C_ALU_OP] = `ALU_ADD;
    #1
    `CHECK_EQ(mem_we,    1'b0,  "add: no write")
    `CHECK_EQ(mem_re,    1'b0,  "add: no read")
    `CHECK_EQ(ld_result, 32'h0, "add: ld_result is 0")

    ctrl = `CTRL_BUBBLE;
    #1 `CHECK_EQ(mem_we, 1'b0, "bubble: no write")

    `TB_FINISH
  end
endmodule
