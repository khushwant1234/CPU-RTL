//=============================================================================
// tb_instr_mem.sv  -  unit test for instr_mem
// Checks: word addressing (addr[31:2]), low 2 bits ignored, combinational
// read, $readmemh-style preload via the memory array.
//=============================================================================
`timescale 1ns/1ps
module tb_instr_mem;
  `include "tb_check.svh"
  `TB_INIT

  logic [31:0] addr, instr_out;

  instr_mem #(.DEPTH(64)) dut (.*);

  initial begin
    $display("tb_instr_mem");

    // preload a pattern: word i = 0xA5A50000 + i
    for (int i = 0; i < 64; i++)
      dut.mem[i] = 32'hA5A5_0000 + i;

    for (int i = 0; i < 64; i++) begin
      addr = i * 4;
      #1 `CHECK_EQ(instr_out, 32'hA5A5_0000 + i, "word read at aligned address")
    end

    // low two address bits select nothing (word aligned memory)
    addr = 32'h0000_0010 | 32'h3;
    #1 `CHECK_EQ(instr_out, 32'hA5A5_0004, "addr[1:0] ignored")

    // read is combinational: new data appears without any clock
    dut.mem[5] = 32'h1234_5678;
    addr = 32'h14;
    #1 `CHECK_EQ(instr_out, 32'h1234_5678, "combinational read after update")

    // last word
    addr = 63 * 4;
    #1 `CHECK_EQ(instr_out, 32'hA5A5_003F, "last word of memory")

    `TB_FINISH
  end
endmodule
