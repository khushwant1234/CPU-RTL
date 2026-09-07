module mem_wb_reg (
    input clk, reset,
    input [31:0] pc_in,
    input [21:0] control_in,
    input [31:0] ldResult_in, instruction_in, aluResult_in,
    output reg [31:0] pc_out,
    output reg [21:0] control_out,
    output reg [31:0] ldResult_out, instruction_out, aluResult_out
);
always @(negedge clk or posedge reset) begin
    if (reset) begin
        pc_out <= 0; control_out <= 0; ldResult_out <= 0;
        instruction_out <= 0; aluResult_out <= 0;
    end else begin
        pc_out <= pc_in; control_out <= control_in;
        ldResult_out <= ldResult_in; instruction_out <= instruction_in;
        aluResult_out <= aluResult_in;
    end
end
endmodule
