//=============================================================================
// ex_mem_reg.v
// EX/MEM pipeline register.
//   alu_result : ALU output (address for ld/st, value for ALU ops)
//   op2        : forwarded rs2 value, this is the store data for st
//   pc         : needed at WB so call can write pc+4 into ra
//   rd_addr/ctrl carried along for forwarding_unit and writeback
//
// Never stalled or flushed: once an instruction reaches EX it always
// completes (branches resolve in EX and only flush the stages behind it).
//=============================================================================
`include "defines.vh"

module ex_mem_reg (
  input  wire               clk,
  input  wire               rst_n,

  input  wire [31:0]        pc_in,
  input  wire [31:0]        alu_result_in,
  input  wire [31:0]        op2_in,
  input  wire [3:0]         rd_addr_in,
  input  wire [`CTRL_W-1:0] ctrl_in,

  output reg  [31:0]        pc_out,
  output reg  [31:0]        alu_result_out,
  output reg  [31:0]        op2_out,
  output reg  [3:0]         rd_addr_out,
  output reg  [`CTRL_W-1:0] ctrl_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out         <= 32'b0;
      alu_result_out <= 32'b0;
      op2_out        <= 32'b0;
      rd_addr_out    <= 4'b0;
      ctrl_out       <= `CTRL_BUBBLE;
    end else begin
      pc_out         <= pc_in;
      alu_result_out <= alu_result_in;
      op2_out        <= op2_in;
      rd_addr_out    <= rd_addr_in;
      ctrl_out       <= ctrl_in;
    end
  end

endmodule
