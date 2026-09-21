//=============================================================================
// tb_forwarding_unit.v  -  unit test for forwarding_unit
// Directed cases for each forwarding path + priority, then random stimulus
// checked against a reference model.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_forwarding_unit;
  `TB_INIT

  reg  [3:0]  ex_rs1_addr, ex_rs2_addr, mem_rd_addr, wb_rd_addr;
  reg         ex_rs1_valid, ex_rs2_valid, mem_reg_write_en, mem_is_load, wb_reg_write_en;
  reg  [31:0] ex_rs1_data = 32'h1111_1111, ex_rs2_data = 32'h2222_2222;
  reg  [31:0] mem_fwd_data = 32'hAAAA_AAAA, wb_fwd_data = 32'hBBBB_BBBB;
  wire [1:0]  fwd_a_sel, fwd_b_sel;
  wire [31:0] op1, op2;

  forwarding_unit dut (
    .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
    .ex_rs1_valid(ex_rs1_valid), .ex_rs2_valid(ex_rs2_valid),
    .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data),
    .mem_rd_addr(mem_rd_addr), .mem_reg_write_en(mem_reg_write_en),
    .mem_is_load(mem_is_load), .mem_fwd_data(mem_fwd_data),
    .wb_rd_addr(wb_rd_addr), .wb_reg_write_en(wb_reg_write_en), .wb_fwd_data(wb_fwd_data),
    .fwd_a_sel(fwd_a_sel), .fwd_b_sel(fwd_b_sel), .op1(op1), .op2(op2)
  );

  task set;
    input [3:0] rs1;
    input       v1;
    input [3:0] rs2;
    input       v2;
    input [3:0] mrd;
    input       mwe, mld;
    input [3:0] wrd;
    input       wwe;
    begin
      ex_rs1_addr = rs1; ex_rs1_valid = v1; ex_rs2_addr = rs2; ex_rs2_valid = v2;
      mem_rd_addr = mrd; mem_reg_write_en = mwe; mem_is_load = mld;
      wb_rd_addr  = wrd; wb_reg_write_en = wwe;
      #1;
    end
  endtask

  // reference model, written independently of the RTL
  function [1:0] ref_sel;
    input [3:0] rs;
    input       v;
    begin
      if (v && mem_reg_write_en && !mem_is_load && mem_rd_addr == rs) ref_sel = `FWD_EX_MEM;
      else if (v && wb_reg_write_en && wb_rd_addr == rs)              ref_sel = `FWD_MEM_WB;
      else                                                            ref_sel = `FWD_NONE;
    end
  endfunction

  integer k;

  initial begin
    $display("tb_forwarding_unit");

    // no dependency
    set(1, 1, 2, 1,  3, 1, 0,  4, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_NONE, "no hazard: A from reg file")
    `CHECK_EQ(fwd_b_sel, `FWD_NONE, "no hazard: B from reg file")
    `CHECK_EQ(op1, 32'h1111_1111, "no hazard: op1 = rs1_data")
    `CHECK_EQ(op2, 32'h2222_2222, "no hazard: op2 = rs2_data")

    // case A: add r1,..  then  sub ..,r1,..
    set(1, 1, 2, 1,  1, 1, 0,  4, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_EX_MEM, "distance 1 on rs1 -> EX/MEM")
    `CHECK_EQ(op1, 32'hAAAA_AAAA, "op1 takes EX/MEM result")
    `CHECK_EQ(fwd_b_sel, `FWD_NONE, "rs2 untouched")

    // case B on rs2
    set(1, 1, 2, 1,  3, 1, 0,  2, 1);
    `CHECK_EQ(fwd_b_sel, `FWD_MEM_WB, "distance 2 on rs2 -> MEM/WB")
    `CHECK_EQ(op2, 32'hBBBB_BBBB, "op2 takes MEM/WB result")

    // both stages write the same reg: newest (EX/MEM) wins
    set(5, 1, 5, 1,  5, 1, 0,  5, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_EX_MEM, "EX/MEM has priority over MEM/WB (A)")
    `CHECK_EQ(fwd_b_sel, `FWD_EX_MEM, "EX/MEM has priority over MEM/WB (B)")

    // rs1 from one stage, rs2 from the other
    set(6, 1, 7, 1,  6, 1, 0,  7, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_EX_MEM, "split: A from EX/MEM")
    `CHECK_EQ(fwd_b_sel, `FWD_MEM_WB, "split: B from MEM/WB")

    // operand not really read (immediate form) -> never forward
    set(1, 1, 3, 0,  3, 1, 0,  3, 1);
    `CHECK_EQ(fwd_b_sel, `FWD_NONE, "rs2_valid=0 (immediate) blocks forwarding")
    set(3, 0, 2, 1,  3, 1, 0,  3, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_NONE, "rs1_valid=0 (mov/not) blocks forwarding")

    // producer does not write a register (st / cmp / branch)
    set(1, 1, 2, 1,  1, 0, 0,  2, 0);
    `CHECK_EQ(fwd_a_sel, `FWD_NONE, "no forward from a non-writing instr in MEM")
    `CHECK_EQ(fwd_b_sel, `FWD_NONE, "no forward from a non-writing instr in WB")

    // load in MEM: data not ready, must not forward the address
    set(1, 1, 2, 1,  1, 1, 1,  9, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_NONE, "load in MEM is not forwarded (hazard unit stalls)")
    // load in WB: forwarded normally
    set(1, 1, 2, 1,  9, 1, 0,  1, 1);
    `CHECK_EQ(fwd_a_sel, `FWD_MEM_WB, "load result forwarded from WB")

    // r15 for ret after call
    set(15, 1, 0, 0,  15, 1, 0,  0, 0);
    `CHECK_EQ(fwd_a_sel, `FWD_EX_MEM, "ret gets ra forwarded from a call in MEM")

    // r0 is a normal register in SimpleRisc, so it forwards too
    set(0, 1, 0, 1,  0, 1, 0,  0, 0);
    `CHECK_EQ(fwd_a_sel, `FWD_EX_MEM, "r0 forwards like any other register")

    // random stimulus vs reference model (regs 0..3 so matches are common)
    for (k = 0; k < 2000; k = k + 1) begin
      set({$random} % 4, $random, {$random} % 4, $random,
          {$random} % 4, $random, $random,
          {$random} % 4, $random);
      `CHECK_EQ_I(fwd_a_sel, ref_sel(ex_rs1_addr, ex_rs1_valid), "random: A select", k)
      `CHECK_EQ_I(fwd_b_sel, ref_sel(ex_rs2_addr, ex_rs2_valid), "random: B select", k)
    end

    `TB_FINISH
  end
endmodule
