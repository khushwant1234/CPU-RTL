//=============================================================================
// flags.v
// E / GT flags register written by cmp in the EX stage.
//   flag_e  = (a == b)
//   flag_gt = (a >  b)   signed compare, SimpleRisc numbers are 2's complement
//
// Updated on the rising edge while cmp is in EX, so a beq/bgt directly after
// the cmp (which is in EX one cycle later) already sees the new flags -- no
// extra forwarding needed for the flags.
//=============================================================================
module flags (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        write_en,   // ctrl[C_FLAGS_WRITE] of the instr in EX
  input  wire [31:0] a,
  input  wire [31:0] b,
  output reg         flag_e,
  output reg         flag_gt
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flag_e  <= 1'b0;
      flag_gt <= 1'b0;
    end else if (write_en) begin
      flag_e  <= (a == b);
      flag_gt <= ($signed(a) > $signed(b));
    end
  end

endmodule
