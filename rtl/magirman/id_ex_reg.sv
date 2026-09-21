//=============================================================================
// id_ex_reg.sv
// ID/EX pipeline register. Carries everything EX/MEM/WB and the
// hazard_unit/forwarding_unit need. rs1_addr/rs2_addr are carried through
// (not just rs1_data/rs2_data) because the forwarding_unit needs to compare
// *this* instruction's source addresses against EX/MEM and MEM/WB stage
// destination addresses -- see design doc Sec 5.1.
//
// On flush (taken branch resolved in EX, see design doc Sec 5.4): load a
// true bubble (ctrl='0 with alu_op forced to ALU_NOP) rather than holding
// or zeroing data fields, so nothing downstream mistakes stale data for a
// live instruction.
//=============================================================================
module id_ex_reg
  import simpleriscprocessor_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  logic         stall,
  input  logic         flush,

  input  logic [31:0]  pc_in,
  input  logic [31:0]  rs1_data_in,
  input  logic [31:0]  rs2_data_in,
  input  logic [31:0]  imm_ext_in,
  input  logic [26:0]  branch_offset_in,
  input  logic [3:0]   rd_addr_in,
  input  logic [3:0]   rs1_addr_in,
  input  logic [3:0]   rs2_addr_in,
  input  ctrl_t         ctrl_in,

  output logic [31:0]  pc_out,
  output logic [31:0]  rs1_data_out,
  output logic [31:0]  rs2_data_out,
  output logic [31:0]  imm_ext_out,
  output logic [26:0]  branch_offset_out,
  output logic [3:0]   rd_addr_out,
  output logic [3:0]   rs1_addr_out,
  output logic [3:0]   rs2_addr_out,
  output ctrl_t         ctrl_out
);

  // Flush (taken branch / load-use bubble) is synchronous, so it is kept out
  // of the async reset branch -- mixing them in one "if" does not map to a
  // clean flop with async reset. Both load CTRL_BUBBLE from the package (a
  // constant, so there is no time-0 race like with an always_comb value).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out            <= 32'b0;
      rs1_data_out       <= 32'b0;
      rs2_data_out       <= 32'b0;
      imm_ext_out        <= 32'b0;
      branch_offset_out  <= 27'b0;
      rd_addr_out        <= 4'b0;
      rs1_addr_out       <= 4'b0;
      rs2_addr_out       <= 4'b0;
      ctrl_out           <= CTRL_BUBBLE;
    end else if (flush) begin
      pc_out            <= 32'b0;
      rs1_data_out       <= 32'b0;
      rs2_data_out       <= 32'b0;
      imm_ext_out        <= 32'b0;
      branch_offset_out  <= 27'b0;
      rd_addr_out        <= 4'b0;
      rs1_addr_out       <= 4'b0;
      rs2_addr_out       <= 4'b0;
      ctrl_out           <= CTRL_BUBBLE;
    end else if (!stall) begin
      pc_out            <= pc_in;
      rs1_data_out       <= rs1_data_in;
      rs2_data_out       <= rs2_data_in;
      imm_ext_out        <= imm_ext_in;
      branch_offset_out  <= branch_offset_in;
      rd_addr_out        <= rd_addr_in;
      rs1_addr_out       <= rs1_addr_in;
      rs2_addr_out       <= rs2_addr_in;
      ctrl_out           <= ctrl_in;
    end
    // else (stall, no flush): hold current outputs
  end

endmodule : id_ex_reg
