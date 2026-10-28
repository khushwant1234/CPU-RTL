`timescale 1ns/1ps

module tb_branch_unit_cosim;

reg jump, branch, branch_gt, is_ret, flag_e, flag_gt;
reg [31:0] branch_target, ret_addr;
wire branch_taken;
wire [31:0] branch_pc;

integer in, out, r;

branch_unit dut(
    .jump(jump),
    .branch(branch),
    .branch_gt(branch_gt),
    .is_ret(is_ret),
    .flag_e(flag_e),
    .flag_gt(flag_gt),
    .branch_target(branch_target),
    .ret_addr(ret_addr),
    .branch_taken(branch_taken),
    .branch_pc(branch_pc)
);

initial begin
    in = $fopen("branch_unit.vec", "r");
    out = $fopen("branch_unit.rtl", "w");
    if (in == 0) begin
        $display("cannot open branch_unit.vec");
        $finish;
    end

    r = $fscanf(in, "%h %h %h %h %h %h %h %h\n", jump, branch, branch_gt, is_ret, flag_e, flag_gt, branch_target, ret_addr);
    while (r == 8) begin
        #1;
        $fdisplay(out, "j=%h br=%h gt=%h ret=%h e=%h g=%h tgt=%h ra=%h -> taken=%h pc=%h",
                  jump, branch, branch_gt, is_ret, flag_e, flag_gt, branch_target, ret_addr, branch_taken, branch_pc);
        r = $fscanf(in, "%h %h %h %h %h %h %h %h\n", jump, branch, branch_gt, is_ret, flag_e, flag_gt, branch_target, ret_addr);
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
