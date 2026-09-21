//=============================================================================
// tb_reg_file.v  -  unit test for reg_file
// Checks: reset clears all 16 regs, write/read on both ports, write enable
// gating, r0 is a normal register (not hardwired), same-cycle write-first
// bypass on both read ports, r14/r15 usable.
//=============================================================================
`timescale 1ns/1ps
`include "tb_check.vh"

module tb_reg_file;
  `TB_INIT

  reg         clk = 0;
  reg         rst_n;
  reg         rd_write_en = 0;
  reg  [3:0]  rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
  reg  [31:0] rd_data = 0;
  wire [31:0] rs1_data, rs2_data;
  integer     r;

  reg_file dut (
    .clk(clk), .rst_n(rst_n),
    .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
    .rd_addr(rd_addr), .rd_data(rd_data), .rd_write_en(rd_write_en),
    .rs1_data(rs1_data), .rs2_data(rs2_data)
  );

  always #5 clk = ~clk;

  task write_reg;
    input [3:0]  rr;
    input [31:0] v;
    begin
      rd_addr = rr; rd_data = v; rd_write_en = 1;
      @(posedge clk); #1;
      rd_write_en = 0;
    end
  endtask

  initial begin
    $display("tb_reg_file");
    rst_n = 0;

    #1;
    for (r = 0; r < 16; r = r + 1) begin
      rs1_addr = r; rs2_addr = r;
      #1 `CHECK_EQ_I(rs1_data, 32'h0, "reset clears register (port 1)", r)
         `CHECK_EQ_I(rs2_data, 32'h0, "reset clears register (port 2)", r)
    end
    rst_n = 1;

    // write every register with a unique value
    for (r = 0; r < 16; r = r + 1)
      write_reg(r, 32'hC0DE_0000 + r * 32'h11);

    for (r = 0; r < 16; r = r + 1) begin
      rs1_addr = r; rs2_addr = 15 - r;
      #1 `CHECK_EQ_I(rs1_data, 32'hC0DE_0000 + r * 32'h11,        "read back on port 1", r)
         `CHECK_EQ_I(rs2_data, 32'hC0DE_0000 + (15 - r) * 32'h11, "read back on port 2", 15 - r)
    end

    // r0 is not hardwired to zero in SimpleRisc
    rs1_addr = 0;
    #1 `CHECK_EQ(rs1_data, 32'hC0DE_0000, "r0 holds a written value")

    // write enable low: no write
    rd_addr = 4'd3; rd_data = 32'hFFFF_FFFF; rd_write_en = 0;
    @(posedge clk); #1;
    rs1_addr = 3;
    #1 `CHECK_EQ(rs1_data, 32'hC0DE_0033, "no write when rd_write_en = 0")

    // write-first bypass: read the reg being written in the same cycle
    rd_addr = 4'd7; rd_data = 32'h1234_5678; rd_write_en = 1;
    rs1_addr = 4'd7; rs2_addr = 4'd7;
    #1 `CHECK_EQ(rs1_data, 32'h1234_5678, "bypass on port 1 before the edge")
       `CHECK_EQ(rs2_data, 32'h1234_5678, "bypass on port 2 before the edge")
    rs2_addr = 4'd8;
    #1 `CHECK_EQ(rs2_data, 32'hC0DE_0088, "no bypass for a different address")
    @(posedge clk); #1;
    rd_write_en = 0;
    #1 `CHECK_EQ(rs1_data, 32'h1234_5678, "value committed after the edge")

    // sp / ra
    write_reg(4'd14, 32'h0000_0FFC);
    write_reg(4'd15, 32'h0000_0020);
    rs1_addr = 14; rs2_addr = 15;
    #1 `CHECK_EQ(rs1_data, 32'h0000_0FFC, "sp (r14) read")
       `CHECK_EQ(rs2_data, 32'h0000_0020, "ra (r15) read")

    // async reset
    rst_n = 0;
    #1 `CHECK_EQ(rs1_data, 32'h0, "async reset clears registers")
    rst_n = 1;

    `TB_FINISH
  end
endmodule
