module pc_reg (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [31:0] pc_next,
  input  wire        stall,
  output reg  [31:0] pc_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc_out <= 32'b0;
    else if (!stall)
      pc_out <= pc_next;
  end

endmodule
