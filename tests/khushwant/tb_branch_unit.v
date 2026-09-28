`timescale 1ns/1ps

module tb_branch_unit;

reg jump, branch, branch_gt, is_ret, flag_e, flag_gt;
reg [31:0] branch_target, ret_addr;
wire branch_taken;
wire [31:0] branch_pc;

integer i;
reg exp_taken;

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

integer errors = 0;
integer tests = 0;
integer failed [0:255];
integer k;

task check;
    input [31:0] got;
    input [31:0] expected;
    input [8*64-1:0] name;
    begin
        tests = tests + 1;
        if (got === expected) begin
            $display("PASS  #%0d  %0s", tests, name);
        end
        else begin
            if (errors < 256)
                failed[errors] = tests;
            errors = errors + 1;
            $display("FAIL  #%0d  %0s   <-------", tests, name);
        end
        $display("      inputs  : jump=%b branch=%b branch_gt=%b is_ret=%b flag_e=%b flag_gt=%b branch_target=%h ret_addr=%h", jump, branch, branch_gt, is_ret, flag_e, flag_gt, branch_target, ret_addr);
        $display("      expected: %0h   actual: %0h   (time %0t)", expected, got, $time);
    end
endtask

initial begin
    $display("tb_branch_unit");
    branch_target = 32'h1000;
    ret_addr = 32'h2000;

    for (i = 0; i < 64; i = i + 1) begin
        {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = i;
        if (branch_gt)
            exp_taken = jump | is_ret | (branch & flag_gt);
        else
            exp_taken = jump | is_ret | (branch & flag_e);
        #1;
        check(branch_taken, exp_taken, "taken (all combos)");
        if (is_ret)
            check(branch_pc, ret_addr, "pc (all combos)");
        else
            check(branch_pc, branch_target, "pc (all combos)");
    end

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b000000;
    #1;
    check(branch_taken, 0, "normal instruction");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b100000;
    #1;
    check(branch_taken, 1, "b taken");
    check(branch_pc, 32'h1000, "b target");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b010010;
    #1;
    check(branch_taken, 1, "beq taken when E=1");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b010001;
    #1;
    check(branch_taken, 0, "beq not taken when GT=1");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b011001;
    #1;
    check(branch_taken, 1, "bgt taken when GT=1");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b011010;
    #1;
    check(branch_taken, 0, "bgt not taken when E=1");

    {jump, branch, branch_gt, is_ret, flag_e, flag_gt} = 6'b000100;
    #1;
    check(branch_taken, 1, "ret taken");
    check(branch_pc, 32'h2000, "ret target");

        $display("");
        $display("%0d checks, %0d passed, %0d failed", tests, tests - errors, errors);
        if (errors == 0) begin
            $display("TB_RESULT: PASS");
        end
        else begin
            $write("failed checks:");
            for (k = 0; k < errors && k < 256; k = k + 1)
                $write(" #%0d", failed[k]);
            $display("");
            $display("TB_RESULT: FAIL");
        end
        $finish;
end

endmodule
