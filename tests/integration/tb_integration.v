`timescale 1ns/1ps
`include "defines.vh"

module tb_integration;

reg clk = 0;
reg rst_n = 0;
wire [31:0] dbg_pc, dbg_wb_data;
wire [3:0] dbg_wb_addr;
wire dbg_wb_en, dbg_stall, dbg_flush;

top_module dut(
    .clk(clk),
    .rst_n(rst_n),
    .dbg_pc(dbg_pc),
    .dbg_wb_en(dbg_wb_en),
    .dbg_wb_addr(dbg_wb_addr),
    .dbg_wb_data(dbg_wb_data),
    .dbg_stall(dbg_stall),
    .dbg_flush(dbg_flush)
);

always #5 clk = ~clk;

integer list, out, r, t, i;
integer max_cycles, reset_at, did_reset, cycles, stalls, flushes, drain, halted, done;
reg [8*256-1:0] hexfile, listfile, outfile;

initial begin
    if (!$value$plusargs("list=%s", listfile)) listfile = "tests.list";
    if (!$value$plusargs("out=%s", outfile)) outfile = "results.txt";
    list = $fopen(listfile, "r");
    out = $fopen(outfile, "w");
    if (list == 0) begin
        $display("cannot open the test list");
        $finish;
    end

    t = 0;
    r = $fscanf(list, "%s %d %d\n", hexfile, max_cycles, reset_at);
    while (r == 3) begin
        rst_n = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            dut.u_imem.mem[i] = `NOP_INSTR;
            dut.u_dmem.mem[i] = 0;
        end
        $readmemh(hexfile, dut.u_imem.mem);
        $fdisplay(out, "T %0d", t);

        @(negedge clk);
        rst_n = 1;
        cycles = 0;
        stalls = 0;
        flushes = 0;
        drain = 0;
        halted = 0;
        done = 0;
        did_reset = 0;

        while (!done) begin
            @(negedge clk);
            if (!halted)
                cycles = cycles + 1;

            if (dut.wb_en)
                $fdisplay(out, "W %0d %h %0d %h", cycles, dut.wb_pc, dut.wb_addr, dut.wb_data);
            if (dut.dmem_we)
                $fdisplay(out, "S %0d %h %h %h", cycles, dut.mem_pc, dut.dmem_addr, dut.dmem_wdata);

            if (halted) begin
                drain = drain - 1;
                if (drain == 0)
                    done = 1;
            end
            else if (dut.ex_branch_taken && dut.ex_ctrl[`C_JUMP] && !dut.ex_ctrl[`C_IS_CALL] && dut.ex_branch_pc == dut.ex_pc) begin
                halted = 1;
                drain = 3;
            end
            else begin
                if (dut.pc_stall) begin
                    stalls = stalls + 1;
                    $fdisplay(out, "L %0d %h %h", cycles, dut.ex_pc, dut.id_pc);
                end
                if (dut.ex_branch_taken) begin
                    flushes = flushes + 1;
                    $fdisplay(out, "F %0d %h %h", cycles, dut.ex_pc, dut.ex_branch_pc);
                end
                if (cycles >= max_cycles)
                    done = 1;
                if (reset_at > 0 && !did_reset && cycles == reset_at) begin
                    rst_n = 0;
                    $fdisplay(out, "X %0d", cycles);
                    @(negedge clk);
                    rst_n = 1;
                    cycles = 0;
                    stalls = 0;
                    flushes = 0;
                    did_reset = 1;
                end
            end
        end

        $fdisplay(out, "E %0d %0d %0d %0d", halted, cycles, stalls, flushes);
        for (i = 0; i < 16; i = i + 1)
            $fdisplay(out, "R %0d %h", i, dut.u_reg_file.regs[i]);
        for (i = 0; i < 1024; i = i + 1)
            if (dut.u_dmem.mem[i] !== 0)
                $fdisplay(out, "M %0d %h", i, dut.u_dmem.mem[i]);

        t = t + 1;
        r = $fscanf(list, "%s %d %d\n", hexfile, max_cycles, reset_at);
    end

    $fclose(list);
    $fclose(out);
    $finish;
end

endmodule
