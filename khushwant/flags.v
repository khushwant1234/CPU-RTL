module flags (
    input clk, reset, isCmp,
    input [31:0] A, B,
    output reg flag_E, flag_GT
);
always @(negedge clk or posedge reset) begin
    if (reset) begin flag_E <= 0; flag_GT <= 0; end
    else if (isCmp) begin
        flag_E <= (A == B);
        flag_GT <= (A > B);
    end
end
endmodule
