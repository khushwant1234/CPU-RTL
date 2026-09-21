//=============================================================================
// flags.sv
// E / GT flags register written by cmp in the EX stage.
//   flag_e  = (a == b)
//   flag_gt = (a >  b)   signed compare, SimpleRisc numbers are 2's complement
//
// Updated on the rising edge while cmp is in EX, so a beq/bgt directly after
// the cmp (which is in EX one cycle later) already sees the new flags -- no
// extra forwarding needed for the flags.
//=============================================================================
module flags (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        write_en,   // ctrl.flags_write_en of the instr in EX
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic        flag_e,
  output logic        flag_gt
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flag_e  <= 1'b0;
      flag_gt <= 1'b0;
    end else if (write_en) begin
      flag_e  <= (a == b);
      flag_gt <= ($signed(a) > $signed(b));
    end
  end

endmodule : flags
