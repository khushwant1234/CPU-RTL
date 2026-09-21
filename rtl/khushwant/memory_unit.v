//=============================================================================
// memory_unit.v
// MA stage: drives the data memory port.
//   address (MAR) = alu_result   (rs1 + imm, computed in EX)
//   data    (MDR) = op2          (value of the stored register)
//
// The port is driven straight from the EX/MEM register and data_mem reads
// combinationally, so ld_result is ready in the same cycle and gets captured
// by MEM/WB (and forwarded from there).
//=============================================================================
`include "defines.vh"

module memory_unit (
  input  wire [`CTRL_W-1:0] ctrl,
  input  wire [31:0]        alu_result,
  input  wire [31:0]        op2,

  // data memory port
  output wire [31:0]        mem_addr,
  output wire [31:0]        mem_wdata,
  output wire               mem_we,
  output wire               mem_re,
  input  wire [31:0]        mem_rdata,

  output wire [31:0]        ld_result
);

  assign mem_addr  = alu_result;
  assign mem_wdata = op2;
  assign mem_we    = ctrl[`C_MEM_WRITE];
  assign mem_re    = ctrl[`C_MEM_READ];

  // only pass real data for loads, keeps the waveform clean for everything else
  assign ld_result = ctrl[`C_MEM_READ] ? mem_rdata : 32'b0;

endmodule
