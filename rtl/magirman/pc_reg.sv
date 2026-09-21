//=============================================================================
// pc_reg.sv
// Program counter register. Updated every cycle unless stalled (load-use
// hazard freeze, driven by hazard_unit).
//=============================================================================
module pc_reg (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] pc_next,   // next PC: pc_out+4, or branch_target on taken branch
  input  logic        stall,     // freeze (hold current pc_out) -- from hazard_unit
  output logic [31:0] pc_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc_out <= 32'b0;
    else if (!stall)
      pc_out <= pc_next;
    // else: hold current value
  end

endmodule : pc_reg
