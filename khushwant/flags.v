module flags (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        write_en,
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
