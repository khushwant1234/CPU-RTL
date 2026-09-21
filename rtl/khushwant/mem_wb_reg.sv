//=============================================================================
// mem_wb_reg.sv
// MEM/WB pipeline register. Holds both the ALU result and the load result;
// writeback picks between them (and pc+4 for call).
//=============================================================================
module mem_wb_reg
  import simpleriscprocessor_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [31:0] pc_in,
  input  logic [31:0] alu_result_in,
  input  logic [31:0] ld_result_in,
  input  logic [3:0]  rd_addr_in,
  input  ctrl_t       ctrl_in,

  output logic [31:0] pc_out,
  output logic [31:0] alu_result_out,
  output logic [31:0] ld_result_out,
  output logic [3:0]  rd_addr_out,
  output ctrl_t       ctrl_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out         <= 32'b0;
      alu_result_out <= 32'b0;
      ld_result_out  <= 32'b0;
      rd_addr_out    <= 4'b0;
      ctrl_out       <= CTRL_BUBBLE;
    end else begin
      pc_out         <= pc_in;
      alu_result_out <= alu_result_in;
      ld_result_out  <= ld_result_in;
      rd_addr_out    <= rd_addr_in;
      ctrl_out       <= ctrl_in;
    end
  end

endmodule : mem_wb_reg
