`timescale 1ns/1ps
`include "defines.vh"

module tb_execute_stage_cosim;

reg clk = 0;
reg rst_n = 1;
reg [31:0] pc, op1, op2, imm_ext;
reg [26:0] branch_offset;
reg [`CTRL_W-1:0] ctrl;
wire [31:0] alu_result, branch_pc;
wire flag_e, flag_gt, branch_taken;

integer in, out, r, done;

execute_stage dut(
    .clk(clk),
    .rst_n(rst_n),
    .pc(pc),
    .op1(op1),
    .op2(op2),
    .imm_ext(imm_ext),
    .branch_offset(branch_offset),
    .ctrl(ctrl),
    .alu_result(alu_result),
    .flag_e(flag_e),
    .flag_gt(flag_gt),
    .branch_taken(branch_taken),
    .branch_pc(branch_pc)
);

always #5 clk = ~clk;

initial begin
    in = $fopen("execute_stage.vec", "r");
    out = $fopen("execute_stage.rtl", "w");
    if (in == 0) begin
        $display("cannot open execute_stage.vec");
        $finish;
    end

    ctrl = `CTRL_BUBBLE;
    #1 rst_n = 0;
    #1 rst_n = 1;

    done = 0;
    while (!done) begin
        @(negedge clk);
        r = $fscanf(in, "%h %h %h %h %h %h\n", pc, op1, op2, imm_ext, branch_offset, ctrl);
        if (r == 6) begin
            #1;
            $fdisplay(out, "pc=%h op1=%h op2=%h imm=%h off=%h ctrl=%h -> res=%h e=%h gt=%h taken=%h bpc=%h",
                      pc, op1, op2, imm_ext, branch_offset, ctrl, alu_result, flag_e, flag_gt, branch_taken, branch_pc);
        end
        else
            done = 1;
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
