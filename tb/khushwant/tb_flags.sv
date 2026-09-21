//=============================================================================
// tb_flags.sv  -  unit test for flags
// Checks: reset, E and GT set on write, signed compare, hold when
// write_en = 0, update is on the clock edge only.
//=============================================================================
`timescale 1ns/1ps
module tb_flags;
  `include "tb_check.svh"
  `TB_INIT

  logic        rst_n;
  logic        clk = 0, write_en = 0;
  logic [31:0] a = 0, b = 0;
  logic        flag_e, flag_gt;

  flags dut (.*);

  always #5 clk = ~clk;

  task automatic cmp(logic [31:0] x, logic [31:0] y, logic exp_e, logic exp_gt, string what);
    a = x; b = y; write_en = 1;
    @(posedge clk); #1;
    write_en = 0;
    `CHECK_EQ(flag_e,  exp_e,  {what, ": E"})
    `CHECK_EQ(flag_gt, exp_gt, {what, ": GT"})
  endtask

  initial begin
    $display("tb_flags");
    rst_n = 0;
    #1 `CHECK_EQ({flag_e, flag_gt}, 2'b00, "reset clears flags")
    rst_n = 1;

    cmp(32'd5,  32'd5,  1, 0, "5 == 5");
    cmp(32'd9,  32'd5,  0, 1, "9 > 5");
    cmp(32'd2,  32'd5,  0, 0, "2 < 5");
    cmp(-32'sd1, 32'd1, 0, 0, "-1 < 1 (signed)");
    cmp(32'd1, -32'sd1, 0, 1, "1 > -1 (signed)");
    cmp(32'h7FFF_FFFF, 32'h8000_0000, 0, 1, "INT_MAX > INT_MIN");
    cmp(-32'sd7, -32'sd7, 1, 0, "-7 == -7");

    // flags hold when write_en is low
    a = 32'd100; b = 32'd1;
    repeat (3) @(posedge clk);
    #1 `CHECK_EQ({flag_e, flag_gt}, 2'b10, "flags hold without write_en")

    // update only happens on the edge
    a = 32'd3; b = 32'd3; write_en = 1;
    cmp(32'd50, 32'd10, 0, 1, "set GT");
    a = 32'd4; b = 32'd4; write_en = 1;
    #2 `CHECK_EQ({flag_e, flag_gt}, 2'b01, "no change before the clock edge")
    @(posedge clk); #1
    `CHECK_EQ({flag_e, flag_gt}, 2'b10, "changes after the clock edge")
    write_en = 0;

    `TB_FINISH
  end
endmodule
