module alu (
    input [31:0] A, B,
    input isAdd, isSub, isCmp, isMul, isDiv, isMod,
    input isLsl, isLsr, isAsr, isOr, isAnd, isNot, isMov,
    output reg [31:0] aluResult
);
always @(*) begin
    aluResult = 32'b0;
    if (isAdd) aluResult = A + B;
    else if (isSub) aluResult = A - B;
    else if (isCmp) aluResult = A - B;
    else if (isMul) aluResult = A * B;
    else if (isDiv) aluResult = A / B;
    else if (isMod) aluResult = A % B;
    else if (isLsl) aluResult = A << B[4:0];
    else if (isLsr) aluResult = A >> B[4:0];
    else if (isAsr) aluResult = $signed(A) >>> B[4:0];
    else if (isOr) aluResult = A | B;
    else if (isAnd) aluResult = A & B;
    else if (isNot) aluResult = ~B;
    else if (isMov) aluResult = B;
end
endmodule
