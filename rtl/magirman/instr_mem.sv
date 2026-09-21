//=============================================================================
// instr_mem.sv
// Behavioral instruction memory for simulation. Word-addressed internally
// (addr[31:2] indexes the array) since every SimpleRisc instruction is a
// 4-byte-aligned 32-bit word. Combinational read -- swap for a synchronous
// SRAM-style model later if your P&R flow requires a real memory macro.
//=============================================================================
module instr_mem #(
  parameter int DEPTH = 1024   // words; resize per your test programs
)(
  input  logic [31:0] addr,       // byte address from pc_reg, must be 4-aligned
  output logic [31:0] instr_out
);

  logic [31:0] mem [0:DEPTH-1];

  // Load a test program here for simulation, e.g.:
  //   initial $readmemh("program.hex", mem);
  // Left commented so each testbench controls its own program load.

  assign instr_out = mem[addr[31:2]];

  // Simple bounds-check assertion for simulation sanity -- not synthesized.
  // synthesis translate_off
  always_comb begin
    if (addr[31:2] >= DEPTH)
      $warning("instr_mem: PC 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
  end
  // synthesis translate_on

endmodule : instr_mem
