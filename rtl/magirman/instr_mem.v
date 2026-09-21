//=============================================================================
// instr_mem.v
// Behavioral instruction memory for simulation. Word-addressed internally
// (addr[31:2] indexes the array) since every SimpleRisc instruction is a
// 4-byte-aligned 32-bit word. Combinational read.
//=============================================================================
module instr_mem #(
  parameter DEPTH = 1024   // words; resize per your test programs
)(
  input  wire [31:0] addr,       // byte address from pc_reg, must be 4-aligned
  output wire [31:0] instr_out
);

  reg [31:0] mem [0:DEPTH-1];

  // Load a test program for simulation from the testbench, e.g.:
  //   $readmemh("program.hex", dut.u_imem.mem);

  assign instr_out = mem[addr[31:2]];

  // Simple bounds check for simulation sanity -- not synthesized.
  // synthesis translate_off
  always @(addr) begin
    if (addr[31:2] >= DEPTH)
      $display("WARNING instr_mem: PC 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
  end
  // synthesis translate_on

endmodule
