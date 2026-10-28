`timescale 1ns/1ps
`include "defines.vh"

module tb_writeback_cosim;

reg [31:0] pc, alu_result, ld_result;
reg [3:0] rd_addr;
reg [`CTRL_W-1:0] ctrl;
wire [3:0] wb_addr;
wire [31:0] wb_data;
wire wb_en;

integer in, out, r;

writeback dut(
    .pc(pc),
    .alu_result(alu_result),
    .ld_result(ld_result),
    .rd_addr(rd_addr),
    .ctrl(ctrl),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .wb_en(wb_en)
);

initial begin
    in = $fopen("writeback.vec", "r");
    out = $fopen("writeback.rtl", "w");
    if (in == 0) begin
        $display("cannot open writeback.vec");
        $finish;
    end

    r = $fscanf(in, "%h %h %h %h %h\n", pc, alu_result, ld_result, rd_addr, ctrl);
    while (r == 5) begin
        #1;
        $fdisplay(out, "pc=%h alu=%h ld=%h rd=%h ctrl=%h -> addr=%h data=%h en=%h",
                  pc, alu_result, ld_result, rd_addr, ctrl, wb_addr, wb_data, wb_en);
        r = $fscanf(in, "%h %h %h %h %h\n", pc, alu_result, ld_result, rd_addr, ctrl);
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
