//=============================================================================
// tb_flags.v  -  unit test for flags
// Checks: reset, E and GT set on write, signed compare, hold when
// write_en = 0, update is on the clock edge only.
//=============================================================================
`timescale 1ns/1ps
`include "tb_check.vh"

module tb_flags;
  `TB_INIT

  reg         clk = 0;
  reg         rst_n;
  reg         write_en = 0;
  reg  [31:0] a = 0, b = 0;
  wire        flag_e, flag_gt;

  flags dut (.clk(clk), .rst_n(rst_n), .write_en(write_en), .a(a), .b(b),
             .flag_e(flag_e), .flag_gt(flag_gt));

  always #5 clk = ~clk;

  task cmp;
    input [31:0]     x, y;
    input            exp_e, exp_gt;
    input [8*32-1:0] what;
    begin
      a = x; b = y; write_en = 1;
      @(posedge clk); #1;
      write_en = 0;
      `CHECK_EQ({flag_e, flag_gt}, {exp_e, exp_gt}, what)
    end
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
    cmp(32'd50, 32'd10, 0, 1, "set GT");
    a = 32'd4; b = 32'd4; write_en = 1;
    #2 `CHECK_EQ({flag_e, flag_gt}, 2'b01, "no change before the clock edge")
    @(posedge clk); #1
    `CHECK_EQ({flag_e, flag_gt}, 2'b10, "changes after the clock edge")
    write_en = 0;

    `TB_FINISH
  end
endmodule
