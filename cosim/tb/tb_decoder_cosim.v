`timescale 1ns/1ps
`include "defines.vh"

module tb_decoder_cosim;

reg [31:0] instr;
wire [3:0] rd_addr, rs1_addr, rs2_addr;
wire [31:0] imm_ext;
wire [26:0] branch_offset;
wire [`CTRL_W-1:0] ctrl;

integer in, out, r;

decoder dut(
    .instr(instr),
    .rd_addr(rd_addr),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .imm_ext(imm_ext),
    .branch_offset(branch_offset),
    .ctrl(ctrl)
);

initial begin
    in = $fopen("decoder.vec", "r");
    out = $fopen("decoder.rtl", "w");
    if (in == 0) begin
        $display("cannot open decoder.vec");
        $finish;
    end

    r = $fscanf(in, "%h\n", instr);
    while (r == 1) begin
        #1;
        $fdisplay(out, "%h -> rd=%h rs1=%h rs2=%h imm=%h off=%h ctrl=%h",
                  instr, rd_addr, rs1_addr, rs2_addr, imm_ext, branch_offset, ctrl);
        r = $fscanf(in, "%h\n", instr);
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
