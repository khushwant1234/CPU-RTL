//=============================================================================
// writeback.v
// RW stage: picks the value written to the register file.
//   call : ra (r15) <- pc + 4
//   ld   : rd <- load result
//   else : rd <- alu result
// wb_data also feeds the MEM/WB forwarding path.
//=============================================================================
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

  // decoder already sets rd_addr = REG_RA for call, forcing it here as well
  // keeps this stage correct on its own
  assign wb_addr = ctrl[`C_IS_CALL] ? `REG_RA : rd_addr;

  assign wb_data = ctrl[`C_IS_CALL]    ? (pc + 32'd4) :
                   ctrl[`C_MEM_TO_REG] ? ld_result    :
                                         alu_result;

  assign wb_en = ctrl[`C_REG_WRITE];

endmodule
