module writeback (
    input [31:0] pc, aluResult, ldResult,
    input [3:0] rd,
    input isLd, isWb, isCall,
    output [3:0] wb_addr,
    output [31:0] wb_data,
    output wb_enable
);
assign wb_addr = isCall ? 4'd15 : rd;
assign wb_data = isCall ? (pc + 32'd4) : (isLd ? ldResult : aluResult);
assign wb_enable = isWb;
endmodule
