//=============================================================================
// ex_mem_reg.sv
// EX/MEM pipeline register.
//   alu_result : ALU output (address for ld/st, value for ALU ops)
//   op2        : forwarded rs2 value, this is the store data for st
//   pc         : needed at WB so call can write pc+4 into ra
//   rd_addr/ctrl carried along for forwarding_unit and writeback
//
// Never stalled or flushed: once an instruction reaches EX it always
// completes (branches resolve in EX and only flush the stages behind it).
//=============================================================================
module ex_mem_reg
  import simpleriscprocessor_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [31:0] pc_in,
  input  logic [31:0] alu_result_in,
  input  logic [31:0] op2_in,
  input  logic [3:0]  rd_addr_in,
  input  ctrl_t       ctrl_in,

  output logic [31:0] pc_out,
  output logic [31:0] alu_result_out,
  output logic [31:0] op2_out,
  output logic [3:0]  rd_addr_out,
  output ctrl_t       ctrl_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out         <= 32'b0;
      alu_result_out <= 32'b0;
      op2_out        <= 32'b0;
      rd_addr_out    <= 4'b0;
      ctrl_out       <= CTRL_BUBBLE;
    end else begin
      pc_out         <= pc_in;
      alu_result_out <= alu_result_in;
      op2_out        <= op2_in;
      rd_addr_out    <= rd_addr_in;
      ctrl_out       <= ctrl_in;
    end
  end

endmodule : ex_mem_reg
