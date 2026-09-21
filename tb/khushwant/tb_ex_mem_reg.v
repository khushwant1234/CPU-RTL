//=============================================================================
// tb_ex_mem_reg.v  -  unit test for ex_mem_reg
// Checks reset to bubble and that every field is captured each cycle.
//=============================================================================
`timescale 1ns/1ps
`include "defines.vh"
`include "tb_check.vh"

module tb_ex_mem_reg;
  `TB_INIT

  reg                clk = 0;
  reg                rst_n;
  reg  [31:0]        pc_in, alu_result_in, op2_in;
  reg  [3:0]         rd_addr_in;
  reg  [`CTRL_W-1:0] ctrl_in;
  wire [31:0]        pc_out, alu_result_out, op2_out;
  wire [3:0]         rd_addr_out;
  wire [`CTRL_W-1:0] ctrl_out;
  integer            i;

  ex_mem_reg dut (
    .clk(clk), .rst_n(rst_n),
    .pc_in(pc_in), .alu_result_in(alu_result_in), .op2_in(op2_in),
    .rd_addr_in(rd_addr_in), .ctrl_in(ctrl_in),
    .pc_out(pc_out), .alu_result_out(alu_result_out), .op2_out(op2_out),
    .rd_addr_out(rd_addr_out), .ctrl_out(ctrl_out)
  );

  always #5 clk = ~clk;

  initial begin
    $display("tb_ex_mem_reg");
    rst_n = 0;
    ctrl_in = `CTRL_BUBBLE; ctrl_in[`C_REG_WRITE] = 1; ctrl_in[`C_ALU_OP] = `ALU_OR;
    pc_in = 32'h10; alu_result_in = 32'h20; op2_in = 32'h30; rd_addr_in = 4'd5;

    #1
    `CHECK_EQ(ctrl_out, `CTRL_BUBBLE, "reset: ctrl is a bubble")
    `CHECK_EQ(alu_result_out, 32'h0, "reset: alu_result cleared")
    `CHECK_EQ(rd_addr_out, 4'h0, "reset: rd cleared")
    rst_n = 1;

    for (i = 0; i < 8; i = i + 1) begin
      pc_in = 32'h1000 + 4 * i; alu_result_in = $random; op2_in = $random;
      rd_addr_in = i; ctrl_in[`C_MEM_WRITE] = i[0]; ctrl_in[`C_MEM_READ] = i[1];
      @(posedge clk); #1
      `CHECK_EQ_I(pc_out, pc_in, "pc captured", i)
      `CHECK_EQ_I(alu_result_out, alu_result_in, "alu_result captured", i)
      `CHECK_EQ_I(op2_out, op2_in, "op2 (store data) captured", i)
      `CHECK_EQ_I(rd_addr_out, rd_addr_in, "rd captured", i)
      `CHECK_EQ_I(ctrl_out, ctrl_in, "ctrl captured", i)
    end

    // output only changes on the edge
    alu_result_in = 32'hFFFF_FFFF;
    #2 `CHECK_TRUE(alu_result_out !== 32'hFFFF_FFFF, "no change between edges")

    `TB_FINISH
  end
endmodule
