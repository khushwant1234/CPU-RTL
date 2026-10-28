`timescale 1ns/1ps

module tb_alu_cosim;

reg [3:0] alu_op;
reg [31:0] a, b;
wire [31:0] result;

integer in, out, r;

alu dut(.a(a), .b(b), .alu_op(alu_op), .result(result));

initial begin
    in = $fopen("alu.vec", "r");
    out = $fopen("alu.rtl", "w");
    if (in == 0) begin
        $display("cannot open alu.vec");
        $finish;
    end

    r = $fscanf(in, "%h %h %h\n", alu_op, a, b);
    while (r == 3) begin
        #1;
        $fdisplay(out, "op=%h a=%h b=%h -> %h", alu_op, a, b, result);
        r = $fscanf(in, "%h %h %h\n", alu_op, a, b);
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
