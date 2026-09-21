//=============================================================================
// data_mem.sv
// Behavioral data memory for simulation, used by memory_unit in the MA stage.
//   - word addressed internally (addr[31:2]), ld/st are 32-bit words
//   - write: synchronous, on the rising edge when we = 1
//   - read : combinational, so the load value is ready within the MA cycle
//            and captured by MEM/WB at the end of it
// Out-of-range reads return 0 and out-of-range writes are dropped (with a
// warning in simulation) so a bad address never corrupts other words.
//=============================================================================
module data_mem #(
  parameter int DEPTH = 1024   // words
)(
  input  logic        clk,
  input  logic        we,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata
);

  logic [31:0] mem [0:DEPTH-1];
  logic [29:0] word;
  logic        in_range;

  assign word     = addr[31:2];
  assign in_range = (word < DEPTH);

  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = 32'b0;
  end

  always_ff @(posedge clk) begin
    if (we && in_range)
      mem[word] <= wdata;
  end

  assign rdata = in_range ? mem[word] : 32'b0;

  // synthesis translate_off
  always_ff @(posedge clk) begin
    if (we && !in_range)
      $warning("data_mem: store to 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
  end
  // synthesis translate_on

endmodule : data_mem
