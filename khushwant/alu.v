module alu (
    input  [31:0] A,
    input  [31:0] B,

    input         isAdd,
    input         isSub,
    input         isCmp,
    input         isMul,
    input         isDiv,
    input         isMod,
    input         isLsl,
    input         isLsr,
    input         isAsr,
    input         isOr,
    input         isAnd,
    input         isNot,
    input         isMov,

    output reg [31:0] aluResult
);

    reg [3:0] aluOp;

    always @(*) begin

        // Select ALU operation
        if (isAdd)      aluOp = 4'd0;
        else if (isSub) aluOp = 4'd1;
        else if (isCmp) aluOp = 4'd2;
        else if (isMul) aluOp = 4'd3;
        else if (isDiv) aluOp = 4'd4;
        else if (isMod) aluOp = 4'd5;
        else if (isLsl) aluOp = 4'd6;
        else if (isLsr) aluOp = 4'd7;
        else if (isAsr) aluOp = 4'd8;
        else if (isOr)  aluOp = 4'd9;
        else if (isAnd) aluOp = 4'd10;
        else if (isNot) aluOp = 4'd11;
        else if (isMov) aluOp = 4'd12;
        else            aluOp = 4'd15;

        // Perform operation
        case (aluOp)
            4'd0: aluResult = A + B;
            4'd1: aluResult = A - B;
            4'd2: aluResult = A - B;              // CMP
            4'd3: aluResult = A * B;
            4'd4: aluResult = A / B;
            4'd5: aluResult = A % B;
            4'd6: aluResult = A << B[4:0];
            4'd7: aluResult = A >> B[4:0];
            4'd8: aluResult = $signed(A) >>> B[4:0];
            4'd9: aluResult = A | B;
            4'd10: aluResult = A & B;
            4'd11: aluResult = ~B;
            4'd12: aluResult = B;
            default: aluResult = 32'b0;
        endcase
    end

endmodule
