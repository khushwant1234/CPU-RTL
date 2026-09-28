`include "defines.vh"

module writeback (
  input  wire [31:0]        pc,
  input  wire [31:0]        alu_result,
  input  wire [31:0]        ld_result,
  input  wire [3:0]         rd_addr,
  input  wire [`CTRL_W-1:0] ctrl,

  output wire [3:0]         wb_addr,
  output wire [31:0]        wb_data,
  output wire               wb_en
);

  assign wb_addr = ctrl[`C_IS_CALL] ? `REG_RA : rd_addr;

  assign wb_data = ctrl[`C_IS_CALL]    ? (pc + 32'd4) :
                   ctrl[`C_MEM_TO_REG] ? ld_result    :
                                         alu_result;

  assign wb_en = ctrl[`C_REG_WRITE];

endmodule
