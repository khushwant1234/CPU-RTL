//=============================================================================
// tb_hazard_unit.v  -  unit test for hazard_unit
// Directed load-use / branch cases, then exhaustive check over a reduced
// register space against a reference model.
//=============================================================================
`timescale 1ns/1ps
`include "tb_check.vh"

module tb_hazard_unit;
  `TB_INIT

  reg  [3:0] id_rs1_addr, id_rs2_addr, ex_rd_addr;
  reg        id_rs1_valid, id_rs2_valid, ex_mem_read_en, branch_taken;
  wire       load_use, pc_stall, if_id_stall, if_id_flush, id_ex_flush;

  hazard_unit dut (
    .id_rs1_addr(id_rs1_addr), .id_rs2_addr(id_rs2_addr),
    .id_rs1_valid(id_rs1_valid), .id_rs2_valid(id_rs2_valid),
    .ex_mem_read_en(ex_mem_read_en), .ex_rd_addr(ex_rd_addr),
    .branch_taken(branch_taken), .load_use(load_use),
    .pc_stall(pc_stall), .if_id_stall(if_id_stall),
    .if_id_flush(if_id_flush), .id_ex_flush(id_ex_flush)
  );

  task set;
    input [3:0] rs1;
    input       v1;
    input [3:0] rs2;
    input       v2;
    input       ld;
    input [3:0] rd;
    input       br;
    begin
      id_rs1_addr = rs1; id_rs1_valid = v1; id_rs2_addr = rs2; id_rs2_valid = v2;
      ex_mem_read_en = ld; ex_rd_addr = rd; branch_taken = br;
      #1;
    end
  endtask

  // outputs packed as {pc_stall, if_id_stall, if_id_flush, id_ex_flush}
  wire [3:0] outs = {pc_stall, if_id_stall, if_id_flush, id_ex_flush};

  integer v;
  reg     lu;

  initial begin
    $display("tb_hazard_unit");

    set(1, 1, 2, 1,  0, 0, 0);
    `CHECK_EQ(outs, 4'b0000, "no hazard: pipeline flows")

    // ld r1 ; add r3, r1, r4
    set(1, 1, 4, 1,  1, 1, 0);
    `CHECK_EQ(load_use, 1'b1, "load-use on rs1 detected")
    `CHECK_EQ(outs, 4'b1101, "load-use on rs1: stall PC+IF/ID, bubble ID/EX")

    // ld r1 ; add r3, r4, r1
    set(4, 1, 1, 1,  1, 1, 0);
    `CHECK_EQ(outs, 4'b1101, "load-use on rs2")

    // ld r1 ; st r1, 0[r2]   (st source is on rs2)
    set(2, 1, 1, 1,  1, 1, 0);
    `CHECK_EQ(outs, 4'b1101, "load then store of the loaded register")

    // ld r15 ; ret
    set(15, 1, 0, 0,  1, 15, 0);
    `CHECK_EQ(outs, 4'b1101, "load of ra followed by ret")

    // ld r1 ; add r3, r4, 1  (imm form: rs2 field == 1 but not valid)
    set(4, 1, 1, 0,  1, 1, 0);
    `CHECK_EQ(outs, 4'b0000, "rs2_valid=0: immediate is not a dependency")

    // add (not a load) in EX writing r1 -> forwarding handles it, no stall
    set(1, 1, 2, 1,  0, 1, 0);
    `CHECK_EQ(outs, 4'b0000, "ALU producer: forwarded, no stall")

    // ld r1 ; add r3, r2, r4 : different register
    set(2, 1, 4, 1,  1, 1, 0);
    `CHECK_EQ(outs, 4'b0000, "load to an unrelated register: no stall")

    // taken branch
    set(1, 1, 2, 1,  0, 0, 1);
    `CHECK_EQ(outs, 4'b0011, "taken branch flushes IF/ID and ID/EX")

    // both at once: branch wins, no stall
    set(1, 1, 2, 1,  1, 1, 1);
    `CHECK_EQ(outs, 4'b0011, "branch + load-use: branch wins, no stall")

    // exhaustive over regs 0..3 and all flag bits
    for (v = 0; v < 1024; v = v + 1) begin
      set(v[1:0], v[2], v[4:3], v[5], v[6], v[8:7], v[9]);
      lu = ex_mem_read_en && ((id_rs1_valid && id_rs1_addr == ex_rd_addr) ||
                              (id_rs2_valid && id_rs2_addr == ex_rd_addr));
      `CHECK_EQ_I(load_use, lu, "exhaustive: load_use", v)
      `CHECK_EQ_I(outs, {lu && !branch_taken, lu && !branch_taken, branch_taken,
                         lu || branch_taken}, "exhaustive: outputs", v)
    end

    `TB_FINISH
  end
endmodule
