//=============================================================================
// tb_pc_reg.sv  -  unit test for pc_reg
// Checks: async reset to 0, normal update, stall hold, reset while running.
//=============================================================================
`timescale 1ns/1ps
module tb_pc_reg;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0, stall = 0;
  logic [31:0] pc_next = 32'h0, pc_out;

  pc_reg dut (.*);

  always #5 clk = ~clk;

  initial begin
    $display("tb_pc_reg");
    rst_n = 0;

    // reset
    pc_next = 32'hDEAD_BEEF;
    #1  `CHECK_EQ(pc_out, 32'h0, "pc is 0 during reset")
    @(posedge clk); #1
    `CHECK_EQ(pc_out, 32'h0, "reset overrides pc_next on clock edge")
    rst_n = 1;

    // normal sequential update
    for (int i = 1; i <= 4; i++) begin
      pc_next = i * 4;
      @(posedge clk); #1
      `CHECK_EQ(pc_out, i * 4, "pc follows pc_next")
    end

    // stall holds the value for several cycles
    stall   = 1;
    pc_next = 32'h100;
    repeat (3) begin
      @(posedge clk); #1
      `CHECK_EQ(pc_out, 32'h10, "pc holds while stalled")
    end
    stall = 0;
    @(posedge clk); #1
    `CHECK_EQ(pc_out, 32'h100, "pc updates once stall drops")

    // branch-style jump
    pc_next = 32'h0000_0400;
    @(posedge clk); #1
    `CHECK_EQ(pc_out, 32'h400, "pc takes a non-sequential target")

    // asynchronous reset in the middle of a cycle
    #2 rst_n = 0;
    #1 `CHECK_EQ(pc_out, 32'h0, "async reset clears pc without a clock edge")
    rst_n = 1;

    `TB_FINISH
  end
endmodule
