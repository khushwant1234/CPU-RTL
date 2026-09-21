//=============================================================================
// tb_cpu.sv  -  integration test for the full pipelined CPU
//
// Runs each program in programs/ (assembled with tools/sr_asm.py) on
// simplerisc_cpu and checks the final register file / data memory, plus the
// number of load-use stalls and taken-branch flushes so the hazard handling
// is checked too, not just the final answer.
//
// A program ends with "b ." (branch to itself). When that branch is taken
// in EX the testbench lets the older instructions drain and then checks.
//
// Waveform: add +vcd on the vvp command line to dump build/tb_cpu.vcd
//=============================================================================
`timescale 1ns/1ps
module tb_cpu;
  import simpleriscprocessor_pkg::*;
  `include "tb_check.svh"
  `TB_INIT

  logic        clk = 0, rst_n;
  logic [31:0] dbg_pc, dbg_wb_data;
  logic [3:0]  dbg_wb_addr;
  logic        dbg_wb_en, dbg_stall, dbg_flush;

  simplerisc_cpu #(.IMEM_DEPTH(1024), .DMEM_DEPTH(1024)) dut (.*);

  always #5 clk = ~clk;

  int cycles, stalls, flushes;
  bit halted;

  // --------------------------------------------------------------------
  // helpers
  // --------------------------------------------------------------------
  function automatic logic [31:0] R(int i);
    return dut.u_reg_file.regs[i];
  endfunction

  function automatic logic [31:0] M(logic [31:0] byte_addr);
    return dut.u_dmem.mem[byte_addr[31:2]];
  endfunction

  task automatic run_program(string name, int max_cycles = 5000);
    string file;
    file = {"programs/", name, ".hex"};
    $display("\n  --- %s ---", name);

    // clear memories, load program, reset
    for (int i = 0; i < 1024; i++) begin
      dut.u_imem.mem[i] = NOP_INSTR;
      dut.u_dmem.mem[i] = 32'b0;
    end
    $readmemh(file, dut.u_imem.mem);

    rst_n = 1;
    #1 rst_n = 0;
    repeat (2) @(posedge clk);
    #1 rst_n = 1;

    cycles = 0; stalls = 0; flushes = 0; halted = 0;
    while (!halted && cycles < max_cycles) begin
      @(negedge clk);
      if (dut.ex_branch_taken && dut.ex_branch_pc == dut.ex_pc) begin
        halted = 1;                    // "b ." reached EX
      end else begin
        if (dbg_stall) stalls++;
        if (dbg_flush) flushes++;
      end
      cycles++;
    end
    // let the instructions ahead of the halt branch finish MEM and WB
    repeat (3) @(posedge clk);
    #1;

    `CHECK_TRUE(halted, {name, ": reached the halt loop (b .)"})
    $display("  cycles=%0d  load-use stalls=%0d  branch flushes=%0d", cycles, stalls, flushes);

    for (int i = 0; i < 16; i++)
      `CHECK_TRUE(^R(i) !== 1'bx, $sformatf("%s: r%0d has no X/Z bits", name, i))
  endtask

  task automatic check_reg(int r, logic [31:0] v, string name);
    `CHECK_EQ(R(r), v, $sformatf("%s: r%0d", name, r))
  endtask

  // --------------------------------------------------------------------
  // tests
  // --------------------------------------------------------------------
  task automatic test_arith();
    string n = "arith";
    run_program(n);
    check_reg(1, 12, n);           check_reg(2, 5, n);
    check_reg(3, 17, n);           check_reg(4, 7, n);
    check_reg(5, 60, n);           check_reg(6, 2, n);
    check_reg(7, 2, n);            check_reg(8, 4, n);
    check_reg(9, 13, n);           check_reg(10, 32'hFFFF_FFFA, n);
    check_reg(11, 40, n);          check_reg(12, -32'sd16, n);
    check_reg(13, 32'hF, n);       check_reg(14, 32'h1234_ABCD, n);
    check_reg(0, -32'sd7, n);      check_reg(15, 32'h0000_FFFF, n);
    `CHECK_EQ(stalls,  0, "arith: no stalls")
    `CHECK_EQ(flushes, 0, "arith: no branches")
  endtask

  task automatic test_forwarding();
    string n = "forwarding";
    run_program(n);
    check_reg(1, 1, n);   check_reg(2, 2, n);   check_reg(3, 3, n);
    check_reg(4, 5, n);   check_reg(5, 8, n);   check_reg(6, 13, n);
    check_reg(7, 21, n);  check_reg(8, 34, n);  check_reg(9, 55, n);
    check_reg(10, 9, n);  check_reg(11, 18, n);
    check_reg(0, 100, n); check_reg(14, ~32'd100, n);
    `CHECK_EQ(M(68), 32'd100, "forwarding: st used the forwarded data/base")
    `CHECK_EQ(stalls, 0, "forwarding: forwarding alone, zero stalls")
  endtask

  task automatic test_load_use();
    string n = "load_use";
    run_program(n);
    check_reg(3, 11, n);  check_reg(4, 22, n);
    check_reg(5, 22, n);  check_reg(6, 44, n);
    check_reg(7, 11, n);  check_reg(8, 11, n);
    check_reg(9, 256, n); check_reg(10, 22, n);
    check_reg(11, 11, n); check_reg(12, 0, n);   check_reg(13, 1, n);
    `CHECK_EQ(M(256 + 8),  32'd11,  "load_use: st of a just-loaded value")
    `CHECK_EQ(M(256 + 12), 32'd256, "load_use: pointer stored")
    `CHECK_EQ(stalls,  4, "load_use: exactly one stall per load-use pair")
    `CHECK_EQ(flushes, 1, "load_use: one taken beq")
  endtask

  task automatic test_branches();
    string n = "branches";
    run_program(n);
    check_reg(3, 1, n);    // not 99/98: wrong-path instrs were flushed
    check_reg(4, 2, n);
    check_reg(5, 3, n);
    check_reg(7, 4, n);
    check_reg(8, 55, n);   // 1 + 2 + ... + 10
    check_reg(9, 11, n);
    check_reg(10, 32'h77, n);
    check_reg(11, 0, n);   // never went to "bad"
    // beq eq_ok, bgt gt_ok, b skip, 9 x "b loop", beq done
    `CHECK_EQ(flushes, 13, "branches: taken branch count")
    `CHECK_EQ(stalls,  0,  "branches: no stalls")
  endtask

  task automatic test_call_ret();
    string n = "call_ret";
    run_program(n);
    check_reg(3, 36, n);          // square(6)
    check_reg(4, 120, n);         // fact(5), recursive
    check_reg(6, 42, n);          // leaf
    check_reg(5, 32'h55, n);
    check_reg(1, 5, n);           // restored from the stack
    check_reg(14, 1024, n);       // sp back where it started
    `CHECK_EQ(M(1024 - 8 + 4) != 0, 1'b1, "call_ret: ra was saved on the stack")
    `CHECK_EQ(stalls,  1,  "call_ret: one load-use (ld ra -> ret)")
    `CHECK_EQ(flushes, 19, "call_ret: taken branches (calls, rets, bgt, b)")
  endtask

  task automatic test_bubble_sort();
    string n = "bubble_sort";
    logic [31:0] exp [8] = '{-32'sd20, -32'sd3, 0, 1, 5, 7, 7, 12};
    run_program(n, 20000);
    foreach (exp[i])
      `CHECK_EQ(M(32'h100 + 4 * i), exp[i], $sformatf("bubble_sort: a[%0d]", i))
    check_reg(8, 9, n);           // sum
  endtask

  // reset in the middle of a run must bring everything back cleanly
  task automatic test_reset_midrun();
    string n = "reset_midrun";
    $display("\n  --- %s ---", n);
    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = NOP_INSTR;
    $readmemh("programs/branches.hex", dut.u_imem.mem);
    rst_n = 0; repeat (2) @(posedge clk); #1 rst_n = 1;
    repeat (15) @(posedge clk);
    #2 rst_n = 0;
    #1
    `CHECK_EQ(dbg_pc, 32'h0, "reset_midrun: pc back to 0")
    `CHECK_EQ(dut.ex_ctrl, CTRL_BUBBLE, "reset_midrun: EX holds a bubble")
    `CHECK_EQ(dut.id_instr, NOP_INSTR, "reset_midrun: IF/ID holds a nop")
    `CHECK_EQ(R(1), 32'h0, "reset_midrun: registers cleared")
    #10 rst_n = 1;
  endtask

  initial begin
    $display("tb_cpu");
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/tb_cpu.vcd");
      $dumpvars(0, tb_cpu);
    end

    test_arith();
    test_forwarding();
    test_load_use();
    test_branches();
    test_call_ret();
    test_bubble_sort();
    test_reset_midrun();

    $display("");
    `TB_FINISH
  end

  initial begin
    #5_000_000;
    $display("  [FAIL] global timeout");
    $display("TB_RESULT: FAIL");
    $finish;
  end
endmodule
