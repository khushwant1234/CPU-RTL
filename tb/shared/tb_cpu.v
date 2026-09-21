//=============================================================================
// tb_cpu.v  -  integration test for the full pipelined CPU
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
`include "defines.vh"
`include "tb_check.vh"

module tb_cpu;
  `TB_INIT

  reg         clk = 0;
  reg         rst_n;
  wire [31:0] dbg_pc, dbg_wb_data;
  wire [3:0]  dbg_wb_addr;
  wire        dbg_wb_en, dbg_stall, dbg_flush;

  simplerisc_cpu #(.IMEM_DEPTH(1024), .DMEM_DEPTH(1024)) dut (
    .clk(clk), .rst_n(rst_n),
    .dbg_pc(dbg_pc), .dbg_wb_en(dbg_wb_en), .dbg_wb_addr(dbg_wb_addr),
    .dbg_wb_data(dbg_wb_data), .dbg_stall(dbg_stall), .dbg_flush(dbg_flush)
  );

  always #5 clk = ~clk;

  integer cycles, stalls, flushes, i;
  reg     halted;

  // --------------------------------------------------------------------
  // helpers
  // --------------------------------------------------------------------
  function [31:0] R;                       // register value
    input integer idx;
    R = dut.u_reg_file.regs[idx];
  endfunction

  function [31:0] M;                       // data memory word at byte address
    input [31:0] byte_addr;
    M = dut.u_dmem.mem[byte_addr[31:2]];
  endfunction

  task run_program;
    input [8*40-1:0] hexfile;
    input integer    max_cycles;
    begin
      $display("\n  --- %0s ---", hexfile);

      // clear memories, load program, reset
      for (i = 0; i < 1024; i = i + 1) begin
        dut.u_imem.mem[i] = `NOP_INSTR;
        dut.u_dmem.mem[i] = 32'b0;
      end
      $readmemh(hexfile, dut.u_imem.mem);

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
          if (dbg_stall) stalls  = stalls + 1;
          if (dbg_flush) flushes = flushes + 1;
        end
        cycles = cycles + 1;
      end
      // let the instructions ahead of the halt branch finish MEM and WB
      repeat (3) @(posedge clk);
      #1;

      `CHECK_TRUE(halted, "reached the halt loop (b .)")
      $display("  cycles=%0d  load-use stalls=%0d  branch flushes=%0d", cycles, stalls, flushes);

      for (i = 0; i < 16; i = i + 1)
        `CHECK_TRUE(^R(i) !== 1'bx, "register has no X/Z bits")
    end
  endtask

  task check_reg;
    input integer idx;
    input [31:0]  v;
    `CHECK_EQ_I(R(idx), v, "register r", idx)
  endtask

  task check_mem;
    input [31:0] byte_addr;
    input [31:0] v;
    `CHECK_EQ_I(M(byte_addr), v, "memory at byte address", byte_addr)
  endtask

  // --------------------------------------------------------------------
  // tests
  // --------------------------------------------------------------------
  task test_arith;
    begin
      run_program("programs/arith.hex", 5000);
      check_reg(1, 12);           check_reg(2, 5);
      check_reg(3, 17);           check_reg(4, 7);
      check_reg(5, 60);           check_reg(6, 2);
      check_reg(7, 2);            check_reg(8, 4);
      check_reg(9, 13);           check_reg(10, 32'hFFFF_FFFA);
      check_reg(11, 40);          check_reg(12, -32'sd16);
      check_reg(13, 32'hF);       check_reg(14, 32'h1234_ABCD);
      check_reg(0, -32'sd7);      check_reg(15, 32'h0000_FFFF);
      `CHECK_EQ(stalls,  0, "arith: no stalls")
      `CHECK_EQ(flushes, 0, "arith: no branches")
    end
  endtask

  task test_forwarding;
    begin
      run_program("programs/forwarding.hex", 5000);
      check_reg(1, 1);   check_reg(2, 2);   check_reg(3, 3);
      check_reg(4, 5);   check_reg(5, 8);   check_reg(6, 13);
      check_reg(7, 21);  check_reg(8, 34);  check_reg(9, 55);
      check_reg(10, 9);  check_reg(11, 18);
      check_reg(0, 100); check_reg(14, ~32'd100);
      check_mem(68, 100);              // st used the forwarded data/base
      `CHECK_EQ(stalls, 0, "forwarding: forwarding alone, zero stalls")
    end
  endtask

  task test_load_use;
    begin
      run_program("programs/load_use.hex", 5000);
      check_reg(3, 11);  check_reg(4, 22);
      check_reg(5, 22);  check_reg(6, 44);
      check_reg(7, 11);  check_reg(8, 11);
      check_reg(9, 256); check_reg(10, 22);
      check_reg(11, 11); check_reg(12, 0);   check_reg(13, 1);
      check_mem(256 + 8,  11);         // st of a just-loaded value
      check_mem(256 + 12, 256);        // pointer stored
      `CHECK_EQ(stalls,  4, "load_use: exactly one stall per load-use pair")
      `CHECK_EQ(flushes, 1, "load_use: one taken beq")
    end
  endtask

  task test_branches;
    begin
      run_program("programs/branches.hex", 5000);
      check_reg(3, 1);     // not 99/98: wrong-path instrs were flushed
      check_reg(4, 2);
      check_reg(5, 3);
      check_reg(7, 4);
      check_reg(8, 55);    // 1 + 2 + ... + 10
      check_reg(9, 11);
      check_reg(10, 32'h77);
      check_reg(11, 0);    // never went to "bad"
      // beq eq_ok, bgt gt_ok, b skip, 9 x "b loop", beq done
      `CHECK_EQ(flushes, 13, "branches: taken branch count")
      `CHECK_EQ(stalls,  0,  "branches: no stalls")
    end
  endtask

  task test_call_ret;
    begin
      run_program("programs/call_ret.hex", 5000);
      check_reg(3, 36);          // square(6)
      check_reg(4, 120);         // fact(5), recursive
      check_reg(6, 42);          // leaf
      check_reg(5, 32'h55);
      check_reg(1, 5);           // restored from the stack
      check_reg(14, 1024);       // sp back where it started
      `CHECK_TRUE(M(1024 - 8 + 4) != 0, "call_ret: ra was saved on the stack")
      `CHECK_EQ(stalls,  1,  "call_ret: one load-use (ld ra -> ret)")
      `CHECK_EQ(flushes, 19, "call_ret: taken branches (calls, rets, bgt, b)")
    end
  endtask

  task test_bubble_sort;
    begin
      run_program("programs/bubble_sort.hex", 20000);
      check_mem(32'h100, -32'sd20);
      check_mem(32'h104, -32'sd3);
      check_mem(32'h108, 0);
      check_mem(32'h10C, 1);
      check_mem(32'h110, 5);
      check_mem(32'h114, 7);
      check_mem(32'h118, 7);
      check_mem(32'h11C, 12);
      check_reg(8, 9);           // sum
    end
  endtask

  // reset in the middle of a run must bring everything back cleanly
  task test_reset_midrun;
    begin
      $display("\n  --- reset in the middle of a run ---");
      for (i = 0; i < 1024; i = i + 1) dut.u_imem.mem[i] = `NOP_INSTR;
      $readmemh("programs/branches.hex", dut.u_imem.mem);
      rst_n = 0; repeat (2) @(posedge clk); #1 rst_n = 1;
      repeat (15) @(posedge clk);
      #2 rst_n = 0;
      #1
      `CHECK_EQ(dbg_pc, 32'h0, "reset_midrun: pc back to 0")
      `CHECK_EQ(dut.ex_ctrl, `CTRL_BUBBLE, "reset_midrun: EX holds a bubble")
      `CHECK_EQ(dut.id_instr, `NOP_INSTR, "reset_midrun: IF/ID holds a nop")
      `CHECK_EQ(R(1), 32'h0, "reset_midrun: registers cleared")
      #10 rst_n = 1;
    end
  endtask

  initial begin
    $display("tb_cpu");
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/tb_cpu.vcd");
      $dumpvars(0, tb_cpu);
    end

    test_arith;
    test_forwarding;
    test_load_use;
    test_branches;
    test_call_ret;
    test_bubble_sort;
    test_reset_midrun;

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
