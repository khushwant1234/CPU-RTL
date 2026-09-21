//=============================================================================
// tb_alu.v  -  unit test for alu
// Directed corner cases for every operation, then random vectors checked
// against a reference model in the testbench.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_alu;
  `TB_INIT

  reg  [31:0] a, b;
  reg  [3:0]  alu_op;
  wire [31:0] result;

  alu dut (.a(a), .b(b), .alu_op(alu_op), .result(result));

  // reference model written separately from the RTL
  function [31:0] ref_model;
    input [3:0]  op;
    input [31:0] x, y;
    reg signed [31:0] xs, ys;
    begin
      xs = x; ys = y;
      case (op)
        `ALU_ADD: ref_model = x + y;
        `ALU_SUB: ref_model = x - y;
        `ALU_CMP: ref_model = x - y;
        `ALU_MUL: ref_model = x * y;
        `ALU_DIV: if (y == 0) ref_model = 0; else ref_model = xs / ys;
        `ALU_MOD: if (y == 0) ref_model = 0; else ref_model = xs % ys;
        `ALU_LSL: ref_model = x << y[4:0];
        `ALU_LSR: ref_model = x >> y[4:0];
        `ALU_ASR: ref_model = xs >>> y[4:0];
        `ALU_OR:  ref_model = x | y;
        `ALU_AND: ref_model = x & y;
        `ALU_NOT: ref_model = ~y;
        `ALU_MOV: ref_model = y;
        default:  ref_model = 0;
      endcase
    end
  endfunction

  task t;
    input [3:0]      op;
    input [31:0]     x, y, expect_val;
    input [8*40-1:0] what;
    begin
      alu_op = op; a = x; b = y;
      #1 `CHECK_EQ(result, expect_val, what)
    end
  endtask

  integer     k, op;
  reg  [31:0] rx, ry;

  initial begin
    $display("tb_alu");

    // add / sub
    t(`ALU_ADD, 32'd7, 32'd5, 32'd12, "add 7+5");
    t(`ALU_ADD, 32'hFFFF_FFFF, 32'd1, 32'd0, "add wraps around");
    t(`ALU_ADD, 32'd10, -32'sd3, 32'd7, "add negative");
    t(`ALU_SUB, 32'd5, 32'd7, -32'sd2, "sub gives negative");
    t(`ALU_SUB, 32'h8000_0000, 32'd1, 32'h7FFF_FFFF, "sub overflow wraps");
    t(`ALU_CMP, 32'd9, 32'd9, 32'd0, "cmp result is a-b");

    // mul
    t(`ALU_MUL, 32'd12, 32'd11, 32'd132, "mul");
    t(`ALU_MUL, -32'sd4, 32'd6, -32'sd24, "mul negative");
    t(`ALU_MUL, 32'h0001_0000, 32'h0001_0000, 32'd0, "mul keeps low 32 bits");

    // div / mod (signed, truncate toward zero like C)
    t(`ALU_DIV, 32'd100, 32'd7, 32'd14, "div");
    t(`ALU_DIV, -32'sd100, 32'd7, -32'sd14, "div negative dividend");
    t(`ALU_DIV, 32'd100, -32'sd7, -32'sd14, "div negative divisor");
    t(`ALU_DIV, 32'd5, 32'd0, 32'd0, "div by zero gives 0");
    t(`ALU_MOD, 32'd100, 32'd7, 32'd2, "mod");
    t(`ALU_MOD, -32'sd100, 32'd7, -32'sd2, "mod keeps sign of dividend");
    t(`ALU_MOD, 32'd5, 32'd0, 32'd0, "mod by zero gives 0");

    // logic
    t(`ALU_AND, 32'hF0F0_1234, 32'h0FF0_FFFF, 32'h00F0_1234, "and");
    t(`ALU_OR,  32'hF000_0000, 32'h0000_000F, 32'hF000_000F, "or");
    t(`ALU_NOT, 32'hDEAD_BEEF, 32'h0000_FFFF, 32'hFFFF_0000, "not uses b only");
    t(`ALU_MOV, 32'hDEAD_BEEF, 32'h1234_5678, 32'h1234_5678, "mov passes b");

    // shifts
    t(`ALU_LSL, 32'h0000_0001, 32'd31, 32'h8000_0000, "lsl by 31");
    t(`ALU_LSL, 32'h0000_0003, 32'd4,  32'h0000_0030, "lsl by 4");
    t(`ALU_LSR, 32'h8000_0000, 32'd31, 32'h0000_0001, "lsr fills zero");
    t(`ALU_ASR, 32'h8000_0000, 32'd4,  32'hF800_0000, "asr fills sign bit");
    t(`ALU_ASR, 32'h4000_0000, 32'd4,  32'h0400_0000, "asr positive");
    t(`ALU_LSL, 32'h0000_0001, 32'd33, 32'h0000_0002, "shift uses b[4:0] only");

    t(`ALU_NOP, 32'h1234, 32'h5678, 32'h0, "nop gives 0");

    // random vectors vs reference model, every op (0..13)
    for (k = 0; k < 200; k = k + 1) begin
      for (op = 0; op < 14; op = op + 1) begin
        rx = $random; ry = $random;
        if (k % 10 == 0) ry = {$random} % 41;   // small b for shifts/div
        t(op, rx, ry, ref_model(op, rx, ry), "random vector");
      end
    end

    `TB_FINISH
  end
endmodule
