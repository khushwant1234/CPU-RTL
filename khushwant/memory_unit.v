module memory_unit (
    input clk, reset,
    input isLd, isSt,
    input [31:0] aluResult, op2,
    output [31:0] mem_addr, mem_wdata,
    output mem_we,
    input [31:0] mem_rdata,
    output [31:0] ldResult
);
reg [31:0] mar, mdr;
always @(negedge clk or posedge reset) begin
    if (reset) begin mar <= 0; mdr <= 0; end
    else begin
        if (isLd || isSt) mar <= aluResult;
        if (isSt) mdr <= op2;
    end
end
assign mem_addr = mar;
assign mem_wdata = mdr;
assign mem_we = isSt;
assign ldResult = mem_rdata;
endmodule
