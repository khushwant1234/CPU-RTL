//=============================================================================
// tb_forwarding_unit.sv  -  unit test for forwarding_unit
// Directed cases for each forwarding path + priority, then random stimulus
// checked against a reference model.
//=============================================================================
`timescale 1ns/1ps
module tb_forwarding_unit;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic [3:0]  ex_rs1_addr, ex_rs2_addr, mem_rd_addr, wb_rd_addr;
  logic        ex_rs1_valid, ex_rs2_valid, mem_reg_write_en, mem_is_load, wb_reg_write_en;
  logic [31:0] ex_rs1_data = 32'h1111_1111, ex_rs2_data = 32'h2222_2222;
  logic [31:0] mem_fwd_data = 32'hAAAA_AAAA, wb_fwd_data = 32'hBBBB_BBBB;
  fwd_sel_e    fwd_a_sel, fwd_b_sel;
  logic [31:0] op1, op2;

  forwarding_unit dut (.*);

  task automatic set(logic [3:0] rs1, logic v1, logic [3:0] rs2, logic v2,
                     logic [3:0] mrd, logic mwe, logic mld,
                     logic [3:0] wrd, logic wwe);
    ex_rs1_addr = rs1; ex_rs1_valid = v1; ex_rs2_addr = rs2; ex_rs2_valid = v2;
    mem_rd_addr = mrd; mem_reg_write_en = mwe; mem_is_load = mld;
    wb_rd_addr  = wrd; wb_reg_write_en = wwe;
    #1;
  endtask

  function automatic fwd_sel_e ref_sel(logic [3:0] rs, logic v);
    if (v && mem_reg_write_en && !mem_is_load && mem_rd_addr == rs) return FWD_EX_MEM;
    if (v && wb_reg_write_en && wb_rd_addr == rs)                   return FWD_MEM_WB;
    return FWD_NONE;
  endfunction

  initial begin
    $display("tb_forwarding_unit");

    // no dependency
    set(1, 1, 2, 1,  3, 1, 0,  4, 1);
    `CHECK_EQ(fwd_a_sel, FWD_NONE, "no hazard: A from reg file")
    `CHECK_EQ(fwd_b_sel, FWD_NONE, "no hazard: B from reg file")
    `CHECK_EQ(op1, 32'h1111_1111, "no hazard: op1 = rs1_data")
    `CHECK_EQ(op2, 32'h2222_2222, "no hazard: op2 = rs2_data")

    // case A: add r1,..  then  sub ..,r1,..
    set(1, 1, 2, 1,  1, 1, 0,  4, 1);
    `CHECK_EQ(fwd_a_sel, FWD_EX_MEM, "distance 1 on rs1 -> EX/MEM")
    `CHECK_EQ(op1, 32'hAAAA_AAAA, "op1 takes EX/MEM result")
    `CHECK_EQ(fwd_b_sel, FWD_NONE, "rs2 untouched")

    // case B on rs2
    set(1, 1, 2, 1,  3, 1, 0,  2, 1);
    `CHECK_EQ(fwd_b_sel, FWD_MEM_WB, "distance 2 on rs2 -> MEM/WB")
    `CHECK_EQ(op2, 32'hBBBB_BBBB, "op2 takes MEM/WB result")

    // both stages write the same reg: newest (EX/MEM) wins
    set(5, 1, 5, 1,  5, 1, 0,  5, 1);
    `CHECK_EQ(fwd_a_sel, FWD_EX_MEM, "EX/MEM has priority over MEM/WB (A)")
    `CHECK_EQ(fwd_b_sel, FWD_EX_MEM, "EX/MEM has priority over MEM/WB (B)")

    // rs1 from one stage, rs2 from the other
    set(6, 1, 7, 1,  6, 1, 0,  7, 1);
    `CHECK_EQ(fwd_a_sel, FWD_EX_MEM, "split: A from EX/MEM")
    `CHECK_EQ(fwd_b_sel, FWD_MEM_WB, "split: B from MEM/WB")

    // operand not really read (immediate form) -> never forward
    set(1, 1, 3, 0,  3, 1, 0,  3, 1);
    `CHECK_EQ(fwd_b_sel, FWD_NONE, "rs2_valid=0 (immediate) blocks forwarding")
    set(3, 0, 2, 1,  3, 1, 0,  3, 1);
    `CHECK_EQ(fwd_a_sel, FWD_NONE, "rs1_valid=0 (mov/not) blocks forwarding")

    // producer does not write a register (st / cmp / branch)
    set(1, 1, 2, 1,  1, 0, 0,  2, 0);
    `CHECK_EQ(fwd_a_sel, FWD_NONE, "no forward from a non-writing instr in MEM")
    `CHECK_EQ(fwd_b_sel, FWD_NONE, "no forward from a non-writing instr in WB")

    // load in MEM: data not ready, must not forward the address
    set(1, 1, 2, 1,  1, 1, 1,  9, 1);
    `CHECK_EQ(fwd_a_sel, FWD_NONE, "load in MEM is not forwarded (hazard unit stalls)")
    // load in WB: forwarded normally
    set(1, 1, 2, 1,  9, 1, 0,  1, 1);
    `CHECK_EQ(fwd_a_sel, FWD_MEM_WB, "load result forwarded from WB")

    // r15 for ret after call
    set(REG_RA, 1, 0, 0,  REG_RA, 1, 0,  0, 0);
    `CHECK_EQ(fwd_a_sel, FWD_EX_MEM, "ret gets ra forwarded from a call in MEM")

    // r0 is a normal register in SimpleRisc, so it forwards too
    set(0, 1, 0, 1,  0, 1, 0,  0, 0);
    `CHECK_EQ(fwd_a_sel, FWD_EX_MEM, "r0 forwards like any other register")

    // random stimulus vs reference model
    for (int k = 0; k < 2000; k++) begin
      set($urandom_range(0, 3), $urandom, $urandom_range(0, 3), $urandom,
          $urandom_range(0, 3), $urandom, $urandom,
          $urandom_range(0, 3), $urandom);
      `CHECK_EQ(fwd_a_sel, ref_sel(ex_rs1_addr, ex_rs1_valid), "random: A select")
      `CHECK_EQ(fwd_b_sel, ref_sel(ex_rs2_addr, ex_rs2_valid), "random: B select")
    end

    `TB_FINISH
  end
endmodule
