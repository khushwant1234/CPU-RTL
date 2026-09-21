//=============================================================================
// memory_unit.sv
// MA stage: drives the data memory port.
//   address (MAR) = alu_result   (rs1 + imm, computed in EX)
//   data    (MDR) = op2          (value of the stored register)
//
// First version latched MAR/MDR on the negedge, which pushed the load result
// half a cycle late. Now the port is driven straight from the EX/MEM
// register and data_mem reads combinationally, so ld_result is ready in the
// same cycle and gets captured by MEM/WB (and forwarded from there).
//=============================================================================
module memory_unit
  import simpleriscprocessor_pkg::*;
(
  input  ctrl_t       ctrl,
  input  logic [31:0] alu_result,
  input  logic [31:0] op2,

  // data memory port
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic        mem_we,
  output logic        mem_re,
  input  logic [31:0] mem_rdata,

  output logic [31:0] ld_result
);

  assign mem_addr  = alu_result;
  assign mem_wdata = op2;
  assign mem_we    = ctrl.mem_write_en;
  assign mem_re    = ctrl.mem_read_en;

  // only pass real data for loads, keeps the waveform clean for everything else
  assign ld_result = ctrl.mem_read_en ? mem_rdata : 32'b0;

endmodule : memory_unit
