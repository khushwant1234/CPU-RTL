`timescale 1ns/1ps

module tb_hazard_unit_cosim;

reg [3:0] id_rs1_addr, id_rs2_addr, ex_rd_addr;
reg id_rs1_valid, id_rs2_valid, ex_mem_read_en, branch_taken;
wire load_use, pc_stall, if_id_stall, if_id_flush, id_ex_flush;

integer in, out, r;

hazard_unit dut(
    .id_rs1_addr(id_rs1_addr),
    .id_rs2_addr(id_rs2_addr),
    .id_rs1_valid(id_rs1_valid),
    .id_rs2_valid(id_rs2_valid),
    .ex_mem_read_en(ex_mem_read_en),
    .ex_rd_addr(ex_rd_addr),
    .branch_taken(branch_taken),
    .load_use(load_use),
    .pc_stall(pc_stall),
    .if_id_stall(if_id_stall),
    .if_id_flush(if_id_flush),
    .id_ex_flush(id_ex_flush)
);

initial begin
    in = $fopen("hazard_unit.vec", "r");
    out = $fopen("hazard_unit.rtl", "w");
    if (in == 0) begin
        $display("cannot open hazard_unit.vec");
        $finish;
    end

    r = $fscanf(in, "%h %h %h %h %h %h %h\n", id_rs1_addr, id_rs2_addr, id_rs1_valid, id_rs2_valid, ex_mem_read_en, ex_rd_addr, branch_taken);
    while (r == 7) begin
        #1;
        $fdisplay(out, "rs1=%h rs2=%h v1=%h v2=%h ld=%h rd=%h taken=%h -> lu=%h pcs=%h ifs=%h iff=%h idf=%h",
                  id_rs1_addr, id_rs2_addr, id_rs1_valid, id_rs2_valid, ex_mem_read_en, ex_rd_addr, branch_taken,
                  load_use, pc_stall, if_id_stall, if_id_flush, id_ex_flush);
        r = $fscanf(in, "%h %h %h %h %h %h %h\n", id_rs1_addr, id_rs2_addr, id_rs1_valid, id_rs2_valid, ex_mem_read_en, ex_rd_addr, branch_taken);
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
