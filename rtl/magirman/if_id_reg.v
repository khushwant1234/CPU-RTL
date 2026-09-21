//=============================================================================
// if_id_reg.v
// IF/ID pipeline register. On flush (taken branch), inserts a true NOP
// instruction rather than zeroing the register -- all-zero bits decode as
// "add r0,r0,r0", which is a real (harmless but non-bubble) instruction,
// not an inert one. stall (load-use hazard) freezes contents in place.
//=============================================================================
`include "defines.vh"

module if_id_reg (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        stall,      // hold current contents (hazard_unit)
  input  wire        flush,      // load NOP_INSTR (taken branch)
  input  wire [31:0] pc_in,
  input  wire [31:0] instr_in,
  output reg  [31:0] pc_out,
  output reg  [31:0] instr_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_out    <= 32'b0;
      instr_out <= `NOP_INSTR;
    end else if (flush) begin
      pc_out    <= pc_in;   // pc still advances/redirects; only instr is bubbled
      instr_out <= `NOP_INSTR;
    end else if (!stall) begin
      pc_out    <= pc_in;
      instr_out <= instr_in;
    end
    // else (stall, no flush): hold current pc_out/instr_out
  end

endmodule
