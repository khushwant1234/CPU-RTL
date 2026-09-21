//=============================================================================
// id_ex_reg.v
// ID/EX pipeline register. Carries everything EX/MEM/WB and the
// hazard_unit/forwarding_unit need. rs1_addr/rs2_addr are carried through
// (not just rs1_data/rs2_data) because the forwarding_unit compares *this*
// instruction's source addresses against EX/MEM and MEM/WB destinations.
//
// On flush (taken branch, or load-use bubble) load a true bubble
// (CTRL_BUBBLE, alu_op = ALU_NOP) so nothing downstream mistakes stale data
// for a live instruction. Flush is synchronous, so it is kept out of the
// async reset branch.
//=============================================================================
`include "defines.vh"

module id_ex_reg (
  input  wire               clk,
  input  wire               rst_n,
  input  wire               stall,
  input  wire               flush,

  input  wire [31:0]        pc_in,
  input  wire [31:0]        rs1_data_in,
  input  wire [31:0]        rs2_data_in,
  input  wire [31:0]        imm_ext_in,
  input  wire [26:0]        branch_offset_in,
  input  wire [3:0]         rd_addr_in,
  input  wire [3:0]         rs1_addr_in,
  input  wire [3:0]         rs2_addr_in,
  input  wire [`CTRL_W-1:0] ctrl_in,

  output reg  [31:0]        pc_out,
  output reg  [31:0]        rs1_data_out,
  output reg  [31:0]        rs2_data_out,
  output reg  [31:0]        imm_ext_out,
  output reg  [26:0]        branch_offset_out,
  output reg  [3:0]         rd_addr_out,
  output reg  [3:0]         rs1_addr_out,
  output reg  [3:0]         rs2_addr_out,
  output reg  [`CTRL_W-1:0] ctrl_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out            <= 32'b0;
      rs1_data_out      <= 32'b0;
      rs2_data_out      <= 32'b0;
      imm_ext_out       <= 32'b0;
      branch_offset_out <= 27'b0;
      rd_addr_out       <= 4'b0;
      rs1_addr_out      <= 4'b0;
      rs2_addr_out      <= 4'b0;
      ctrl_out          <= `CTRL_BUBBLE;
    end else if (flush) begin
      pc_out            <= 32'b0;
      rs1_data_out      <= 32'b0;
      rs2_data_out      <= 32'b0;
      imm_ext_out       <= 32'b0;
      branch_offset_out <= 27'b0;
      rd_addr_out       <= 4'b0;
      rs1_addr_out      <= 4'b0;
      rs2_addr_out      <= 4'b0;
      ctrl_out          <= `CTRL_BUBBLE;
    end else if (!stall) begin
      pc_out            <= pc_in;
      rs1_data_out      <= rs1_data_in;
      rs2_data_out      <= rs2_data_in;
      imm_ext_out       <= imm_ext_in;
      branch_offset_out <= branch_offset_in;
      rd_addr_out       <= rd_addr_in;
      rs1_addr_out      <= rs1_addr_in;
      rs2_addr_out      <= rs2_addr_in;
      ctrl_out          <= ctrl_in;
    end
    // else (stall, no flush): hold current outputs
  end

endmodule
