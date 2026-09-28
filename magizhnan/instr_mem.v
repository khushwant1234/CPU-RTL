module instr_mem #(
  parameter DEPTH = 1024
)(
  input  wire [31:0] addr,
  output wire [31:0] instr_out
);

  reg [31:0] mem [0:DEPTH-1];

  assign instr_out = mem[addr[31:2]];

  always @(addr) begin
    if (addr[31:2] >= DEPTH)
      $display("WARNING instr_mem: PC 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
  end

endmodule
