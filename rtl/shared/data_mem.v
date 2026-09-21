//=============================================================================
// data_mem.v
// Behavioral data memory for simulation, used by memory_unit in the MA stage.
//   - word addressed internally (addr[31:2]), ld/st are 32-bit words
//   - write: synchronous, on the rising edge when we = 1
//   - read : combinational, so the load value is ready within the MA cycle
//            and captured by MEM/WB at the end of it
// Out-of-range reads return 0 and out-of-range writes are dropped (with a
// warning in simulation) so a bad address never corrupts other words.
//=============================================================================
module data_mem #(
  parameter DEPTH = 1024   // words
)(
  input  wire        clk,
  input  wire        we,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  output wire [31:0] rdata
);

  reg  [31:0] mem [0:DEPTH-1];
  wire [29:0] word     = addr[31:2];
  wire        in_range = (word < DEPTH);
  integer i;

  initial begin
    for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'b0;
  end

  always @(posedge clk) begin
    if (we && in_range)
      mem[word] <= wdata;
  end

  assign rdata = in_range ? mem[word] : 32'b0;

  // synthesis translate_off
  always @(posedge clk) begin
    if (we && !in_range)
      $display("WARNING data_mem: store to 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
  end
  // synthesis translate_on

endmodule
