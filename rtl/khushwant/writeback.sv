//=============================================================================
// writeback.sv
// RW stage: picks the value written to the register file.
//   call : ra (r15) <- pc + 4
//   ld   : rd <- load result
//   else : rd <- alu result
// wb_data also feeds the MEM/WB forwarding path.
//=============================================================================
module writeback
  import simpleriscprocessor_pkg::*;
(
  input  logic [31:0] pc,
  input  logic [31:0] alu_result,
  input  logic [31:0] ld_result,
  input  logic [3:0]  rd_addr,
  input  ctrl_t       ctrl,

  output logic [3:0]  wb_addr,
  output logic [31:0] wb_data,
  output logic        wb_en
);

  // decoder already sets rd_addr = REG_RA for call, forcing it here as well
  // keeps this stage correct on its own
  assign wb_addr = ctrl.is_call ? REG_RA : rd_addr;

  assign wb_data = ctrl.is_call    ? (pc + 32'd4) :
                   ctrl.mem_to_reg ? ld_result    :
                                     alu_result;

  assign wb_en = ctrl.reg_write_en;

endmodule : writeback
