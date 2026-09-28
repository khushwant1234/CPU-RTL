`include "defines.vh"

module memory_unit (
  input  wire [`CTRL_W-1:0] ctrl,
  input  wire [31:0]        alu_result,
  input  wire [31:0]        op2,

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

  assign ld_result = ctrl[`C_MEM_READ] ? mem_rdata : 32'b0;

endmodule
