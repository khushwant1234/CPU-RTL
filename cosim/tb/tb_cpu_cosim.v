`timescale 1ns/1ps
`include "defines.vh"

module tb_cpu_cosim;

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

integer n, p, i, out;
integer cycles, drain, halted, timeout;
integer total_cycles, stalls, flushes, fwd_exmem, fwd_memwb;
reg [31:0] halt_pc;
reg [8*64-1:0] file;

initial begin
    if (!$value$plusargs("n=%d", n))
        n = 1;
    out = $fopen("cpu.rtl", "w");
    total_cycles = 0;
    stalls = 0;
    flushes = 0;
    fwd_exmem = 0;
    fwd_memwb = 0;

    for (p = 0; p < n; p = p + 1) begin
        rst_n = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            dut.u_imem.mem[i] = `NOP_INSTR;
            dut.u_dmem.mem[i] = 0;
        end
        $sformat(file, "progs/prog_%0d.hex", p);
        $readmemh(file, dut.u_imem.mem);
        $fdisplay(out, "# prog %0d", p);

        @(negedge clk);
        rst_n = 1;
        cycles = 0;
        drain = 0;
        halted = 0;
        timeout = 0;

        while (!halted) begin
            @(negedge clk);
            if (dut.wb_en)
                $fdisplay(out, "W pc=%h r%0d=%h", dut.wb_pc, dut.wb_addr, dut.wb_data);
            if (dut.dmem_we)
                $fdisplay(out, "S pc=%h mem[%h]=%h", dut.mem_pc, dut.dmem_addr, dut.dmem_wdata);

            if (drain > 0) begin
                drain = drain - 1;
                if (drain == 0)
                    halted = 1;
            end
            else if (dut.ex_branch_taken && dut.ex_ctrl[`C_JUMP] && !dut.ex_ctrl[`C_IS_CALL] && dut.ex_branch_pc == dut.ex_pc) begin
                halt_pc = dut.ex_pc;
                drain = 3;
            end
            else begin
                cycles = cycles + 1;
                if (dut.pc_stall)
                    stalls = stalls + 1;
                if (dut.ex_branch_taken)
                    flushes = flushes + 1;
                if (dut.fwd_a_sel == `FWD_EX_MEM) fwd_exmem = fwd_exmem + 1;
                if (dut.fwd_b_sel == `FWD_EX_MEM) fwd_exmem = fwd_exmem + 1;
                if (dut.fwd_a_sel == `FWD_MEM_WB) fwd_memwb = fwd_memwb + 1;
                if (dut.fwd_b_sel == `FWD_MEM_WB) fwd_memwb = fwd_memwb + 1;
                if (cycles > 100000) begin
                    timeout = 1;
                    halted = 1;
                end
            end
        end

        if (timeout)
            $fdisplay(out, "TIMEOUT");
        else
            $fdisplay(out, "H pc=%h", halt_pc);
        total_cycles = total_cycles + cycles;
    end

    $fclose(out);
    $display("cycles=%0d stalls=%0d flushes=%0d fwd_exmem=%0d fwd_memwb=%0d",
             total_cycles, stalls, flushes, fwd_exmem, fwd_memwb);
    $finish;
end

endmodule
