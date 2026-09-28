module data_mem #(parameter DEPTH = 1024) (
    input clk,
    input we,
    input [31:0] addr,
    input [31:0] wdata,
    output [31:0] rdata
);

reg [31:0] mem [0:DEPTH-1];
wire [29:0] index;
wire valid;
integer i;

assign index = addr[31:2];
assign valid = (index < DEPTH);

initial begin
    for (i = 0; i < DEPTH; i = i + 1)
        mem[i] = 0;
end

always @(posedge clk) begin
    if (we && valid)
        mem[index] <= wdata;
    if (we && !valid)
        $display("WARNING data_mem: store to 0x%08h out of range (DEPTH=%0d words)", addr, DEPTH);
end

assign rdata = valid ? mem[index] : 32'd0;

endmodule
