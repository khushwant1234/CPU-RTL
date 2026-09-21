//=============================================================================
// tb_hazard_unit.sv  -  unit test for hazard_unit
// Directed load-use / branch cases, then exhaustive check over a reduced
// register space against a reference model.
//=============================================================================
`timescale 1ns/1ps
module tb_hazard_unit;
  `include "tb_check.svh"
  `TB_INIT

  logic [3:0] id_rs1_addr, id_rs2_addr, ex_rd_addr;
  logic       id_rs1_valid, id_rs2_valid, ex_mem_read_en, branch_taken;
  logic       load_use, pc_stall, if_id_stall, if_id_flush, id_ex_flush;

  hazard_unit dut (.*);

  task automatic set(logic [3:0] rs1, logic v1, logic [3:0] rs2, logic v2,
                     logic ld, logic [3:0] rd, logic br);
    id_rs1_addr = rs1; id_rs1_valid = v1; id_rs2_addr = rs2; id_rs2_valid = v2;
    ex_mem_read_en = ld; ex_rd_addr = rd; branch_taken = br;
    #1;
  endtask

  task automatic expect_out(logic pcs, logic ifs, logic iffl, logic idf, string what);
    `CHECK_EQ({pc_stall, if_id_stall, if_id_flush, id_ex_flush}, {pcs, ifs, iffl, idf}, what)
  endtask

  initial begin
    $display("tb_hazard_unit");

    set(1, 1, 2, 1,  0, 0, 0);
    expect_out(0, 0, 0, 0, "no hazard: pipeline flows");

    // ld r1 ; add r3, r1, r4
    set(1, 1, 4, 1,  1, 1, 0);
    `CHECK_EQ(load_use, 1'b1, "load-use on rs1 detected")
    expect_out(1, 1, 0, 1, "load-use on rs1: stall PC+IF/ID, bubble ID/EX");

    // ld r1 ; add r3, r4, r1
    set(4, 1, 1, 1,  1, 1, 0);
    expect_out(1, 1, 0, 1, "load-use on rs2");

    // ld r1 ; st r1, 0[r2]   (st source is on rs2)
    set(2, 1, 1, 1,  1, 1, 0);
    expect_out(1, 1, 0, 1, "load then store of the loaded register");

    // ld r15 ; ret
    set(15, 1, 0, 0,  1, 15, 0);
    expect_out(1, 1, 0, 1, "load of ra followed by ret");

    // ld r1 ; add r3, r4, 1  (imm form: rs2 field garbage == 1 but not valid)
    set(4, 1, 1, 0,  1, 1, 0);
    expect_out(0, 0, 0, 0, "rs2_valid=0: immediate is not a dependency");

    // add (not a load) in EX writing r1 -> forwarding handles it, no stall
    set(1, 1, 2, 1,  0, 1, 0);
    expect_out(0, 0, 0, 0, "ALU producer: forwarded, no stall");

    // ld r1 ; add r3, r2, r4 : different register
    set(2, 1, 4, 1,  1, 1, 0);
    expect_out(0, 0, 0, 0, "load to an unrelated register: no stall");

    // taken branch
    set(1, 1, 2, 1,  0, 0, 1);
    expect_out(0, 0, 1, 1, "taken branch flushes IF/ID and ID/EX");

    // both at once: branch wins, no stall
    set(1, 1, 2, 1,  1, 1, 1);
    expect_out(0, 0, 1, 1, "branch + load-use: branch wins, no stall");

    // exhaustive over regs 0..3 and all flag bits
    for (int v = 0; v < (1 << 11); v++) begin
      logic lu;
      set(v[1:0], v[2], v[4:3], v[5], v[6], v[8:7], v[9]);
      lu = ex_mem_read_en && ((id_rs1_valid && id_rs1_addr == ex_rd_addr) ||
                              (id_rs2_valid && id_rs2_addr == ex_rd_addr));
      `CHECK_EQ(load_use, lu, "exhaustive: load_use")
      expect_out(lu && !branch_taken, lu && !branch_taken, branch_taken,
                 lu || branch_taken, "exhaustive: outputs");
    end

    `TB_FINISH
  end
endmodule
