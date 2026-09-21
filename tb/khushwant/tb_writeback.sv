//=============================================================================
// tb_writeback.sv  -  unit test for writeback
// Checks the three write-back sources and the write enable.
//=============================================================================
`timescale 1ns/1ps
module tb_writeback;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic [31:0] pc = 32'h0000_0100, alu_result = 32'hAAAA_AAAA, ld_result = 32'h5555_5555;
  logic [3:0]  rd_addr = 4'd3;
  ctrl_t       ctrl;
  logic [3:0]  wb_addr;
  logic [31:0] wb_data;
  logic        wb_en;

  writeback dut (.*);

  initial begin
    $display("tb_writeback");

    ctrl = CTRL_BUBBLE; ctrl.reg_write_en = 1; ctrl.alu_op = ALU_ADD;
    #1
    `CHECK_EQ(wb_data, 32'hAAAA_AAAA, "alu instruction writes alu_result")
    `CHECK_EQ(wb_addr, 4'd3, "alu instruction writes rd")
    `CHECK_EQ(wb_en,   1'b1, "alu instruction write enable")

    ctrl.mem_to_reg = 1; ctrl.mem_read_en = 1;
    #1
    `CHECK_EQ(wb_data, 32'h5555_5555, "ld writes ld_result")
    `CHECK_EQ(wb_addr, 4'd3, "ld writes rd")

    ctrl = CTRL_BUBBLE; ctrl.jump = 1; ctrl.is_call = 1; ctrl.reg_write_en = 1;
    rd_addr = 4'd0;
    #1
    `CHECK_EQ(wb_data, 32'h0000_0104, "call writes pc + 4")
    `CHECK_EQ(wb_addr, REG_RA, "call writes r15 even if rd is something else")
    `CHECK_EQ(wb_en,   1'b1, "call write enable")

    ctrl = CTRL_BUBBLE; ctrl.mem_write_en = 1;
    #1 `CHECK_EQ(wb_en, 1'b0, "st does not write a register")
    ctrl = CTRL_BUBBLE; ctrl.flags_write_en = 1; ctrl.alu_op = ALU_CMP;
    #1 `CHECK_EQ(wb_en, 1'b0, "cmp does not write a register")
    ctrl = CTRL_BUBBLE;
    #1 `CHECK_EQ(wb_en, 1'b0, "bubble does not write a register")

    `TB_FINISH
  end
endmodule
