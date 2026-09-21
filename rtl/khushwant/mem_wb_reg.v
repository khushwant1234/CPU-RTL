//=============================================================================
// mem_wb_reg.v
// MEM/WB pipeline register. Holds both the ALU result and the load result;
// writeback picks between them (and pc+4 for call).
//=============================================================================
`include "defines.vh"

module mem_wb_reg (
  input  wire               clk,
  input  wire               rst_n,

  input  wire [31:0]        pc_in,
  input  wire [31:0]        alu_result_in,
  input  wire [31:0]        ld_result_in,
  input  wire [3:0]         rd_addr_in,
  input  wire [`CTRL_W-1:0] ctrl_in,

  output reg  [31:0]        pc_out,
  output reg  [31:0]        alu_result_out,
  output reg  [31:0]        ld_result_out,
  output reg  [3:0]         rd_addr_out,
  output reg  [`CTRL_W-1:0] ctrl_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out         <= 32'b0;
      alu_result_out <= 32'b0;
      ld_result_out  <= 32'b0;
      rd_addr_out    <= 4'b0;
      ctrl_out       <= `CTRL_BUBBLE;
    end else begin
      pc_out         <= pc_in;
      alu_result_out <= alu_result_in;
      ld_result_out  <= ld_result_in;
      rd_addr_out    <= rd_addr_in;
      ctrl_out       <= ctrl_in;
    end
  end

endmodule
