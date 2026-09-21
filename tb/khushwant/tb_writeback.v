//=============================================================================
// tb_writeback.v  -  unit test for writeback
// Checks the three write-back sources and the write enable.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_writeback;
  `TB_INIT

  reg  [31:0]        pc = 32'h0000_0100, alu_result = 32'hAAAA_AAAA, ld_result = 32'h5555_5555;
  reg  [3:0]         rd_addr = 4'd3;
  reg  [`CTRL_W-1:0] ctrl;
  wire [3:0]         wb_addr;
  wire [31:0]        wb_data;
  wire               wb_en;

  writeback dut (
    .pc(pc), .alu_result(alu_result), .ld_result(ld_result), .rd_addr(rd_addr),
    .ctrl(ctrl), .wb_addr(wb_addr), .wb_data(wb_data), .wb_en(wb_en)
  );

  initial begin
    $display("tb_writeback");

    ctrl = `CTRL_BUBBLE; ctrl[`C_REG_WRITE] = 1; ctrl[`C_ALU_OP] = `ALU_ADD;
    #1
    `CHECK_EQ(wb_data, 32'hAAAA_AAAA, "alu instruction writes alu_result")
    `CHECK_EQ(wb_addr, 4'd3, "alu instruction writes rd")
    `CHECK_EQ(wb_en,   1'b1, "alu instruction write enable")

    ctrl[`C_MEM_TO_REG] = 1; ctrl[`C_MEM_READ] = 1;
    #1
    `CHECK_EQ(wb_data, 32'h5555_5555, "ld writes ld_result")
    `CHECK_EQ(wb_addr, 4'd3, "ld writes rd")

    ctrl = `CTRL_BUBBLE; ctrl[`C_JUMP] = 1; ctrl[`C_IS_CALL] = 1; ctrl[`C_REG_WRITE] = 1;
    rd_addr = 4'd0;
    #1
    `CHECK_EQ(wb_data, 32'h0000_0104, "call writes pc + 4")
    `CHECK_EQ(wb_addr, `REG_RA, "call writes r15 even if rd is something else")
    `CHECK_EQ(wb_en,   1'b1, "call write enable")

    ctrl = `CTRL_BUBBLE; ctrl[`C_MEM_WRITE] = 1;
    #1 `CHECK_EQ(wb_en, 1'b0, "st does not write a register")
    ctrl = `CTRL_BUBBLE; ctrl[`C_FLAGS_WRITE] = 1; ctrl[`C_ALU_OP] = `ALU_CMP;
    #1 `CHECK_EQ(wb_en, 1'b0, "cmp does not write a register")
    ctrl = `CTRL_BUBBLE;
    #1 `CHECK_EQ(wb_en, 1'b0, "bubble does not write a register")

    `TB_FINISH
  end
endmodule
