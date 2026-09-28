`include "defines.vh"

module if_id_reg (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        stall,
  input  wire        flush,
  input  wire [31:0] pc_in,
  input  wire [31:0] instr_in,
  output reg  [31:0] pc_out,
  output reg  [31:0] instr_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out    <= 32'b0;
      instr_out <= `NOP_INSTR;
    end else if (flush) begin
      pc_out    <= pc_in;
      instr_out <= `NOP_INSTR;
    end else if (!stall) begin
      pc_out    <= pc_in;
      instr_out <= instr_in;
    end
  end

endmodule
