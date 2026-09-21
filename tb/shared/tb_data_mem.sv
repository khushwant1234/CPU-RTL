//=============================================================================
// tb_data_mem.sv  -  unit test for data_mem
// Checks: memory starts at 0, synchronous write, combinational read,
// write enable gating, word addressing, out-of-range accesses.
//=============================================================================
`timescale 1ns/1ps
module tb_data_mem;
  `include "tb_check.svh"
  `TB_INIT

  logic        clk = 0, we = 0;
  logic [31:0] addr = 0, wdata = 0, rdata;

  data_mem #(.DEPTH(64)) dut (.*);

  always #5 clk = ~clk;

  task automatic store(logic [31:0] a, logic [31:0] d);
    addr = a; wdata = d; we = 1;
    @(posedge clk); #1;
    we = 0;
  endtask

  initial begin
    $display("tb_data_mem");

    addr = 32'h10;
    #1 `CHECK_EQ(rdata, 32'h0, "memory starts cleared")

    // write then read every word
    for (int i = 0; i < 64; i++) store(i * 4, 32'hD000_0000 + i);
    for (int i = 0; i < 64; i++) begin
      addr = i * 4;
      #1 `CHECK_EQ(rdata, 32'hD000_0000 + i, "read back stored word")
    end

    // write is synchronous: not visible before the edge
    addr = 32'h20; wdata = 32'hFEED_BEEF; we = 1;
    #1 `CHECK_EQ(rdata, 32'hD000_0008, "old value until the clock edge")
    @(posedge clk); #1
    `CHECK_EQ(rdata, 32'hFEED_BEEF, "new value after the clock edge")
    we = 0;

    // we = 0 -> no write
    addr = 32'h24; wdata = 32'h1234_5678;
    @(posedge clk); #1
    `CHECK_EQ(rdata, 32'hD000_0009, "no write when we = 0")

    // low 2 bits ignored
    addr = 32'h27;
    #1 `CHECK_EQ(rdata, 32'hD000_0009, "addr[1:0] ignored")

    // out of range
    addr = 64 * 4;
    #1 `CHECK_EQ(rdata, 32'h0, "out-of-range read returns 0")
    store(64 * 4, 32'hBAD0_BAD0);
    addr = 0;
    #1 `CHECK_EQ(rdata, 32'hD000_0000, "out-of-range write does not wrap onto word 0")

    `TB_FINISH
  end
endmodule
