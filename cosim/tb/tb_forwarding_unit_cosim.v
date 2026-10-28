`timescale 1ns/1ps

module tb_forwarding_unit_cosim;

reg [3:0] ex_rs1_addr, ex_rs2_addr, mem_rd_addr, wb_rd_addr;
reg ex_rs1_valid, ex_rs2_valid, mem_reg_write_en, mem_is_load, wb_reg_write_en;
reg [31:0] ex_rs1_data, ex_rs2_data, mem_fwd_data, wb_fwd_data;
wire [1:0] fwd_a_sel, fwd_b_sel;
wire [31:0] op1, op2;

integer in, out, r;

forwarding_unit dut(
    .ex_rs1_addr(ex_rs1_addr),
    .ex_rs2_addr(ex_rs2_addr),
    .ex_rs1_valid(ex_rs1_valid),
    .ex_rs2_valid(ex_rs2_valid),
    .ex_rs1_data(ex_rs1_data),
    .ex_rs2_data(ex_rs2_data),
    .mem_rd_addr(mem_rd_addr),
    .mem_reg_write_en(mem_reg_write_en),
    .mem_is_load(mem_is_load),
    .mem_fwd_data(mem_fwd_data),
    .wb_rd_addr(wb_rd_addr),
    .wb_reg_write_en(wb_reg_write_en),
    .wb_fwd_data(wb_fwd_data),
    .fwd_a_sel(fwd_a_sel),
    .fwd_b_sel(fwd_b_sel),
    .op1(op1),
    .op2(op2)
);

task read_line;
    begin
        r = $fscanf(in, "%h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                    ex_rs1_addr, ex_rs2_addr, ex_rs1_valid, ex_rs2_valid, ex_rs1_data, ex_rs2_data,
                    mem_rd_addr, mem_reg_write_en, mem_is_load, mem_fwd_data,
                    wb_rd_addr, wb_reg_write_en, wb_fwd_data);
    end
endtask

initial begin
    in = $fopen("forwarding_unit.vec", "r");
    out = $fopen("forwarding_unit.rtl", "w");
    if (in == 0) begin
        $display("cannot open forwarding_unit.vec");
        $finish;
    end

    read_line;
    while (r == 13) begin
        #1;
        $fdisplay(out, "rs1=%h rs2=%h v1=%h v2=%h d1=%h d2=%h mrd=%h mw=%h mld=%h md=%h wrd=%h ww=%h wd=%h -> a=%h b=%h op1=%h op2=%h",
                  ex_rs1_addr, ex_rs2_addr, ex_rs1_valid, ex_rs2_valid, ex_rs1_data, ex_rs2_data,
                  mem_rd_addr, mem_reg_write_en, mem_is_load, mem_fwd_data,
                  wb_rd_addr, wb_reg_write_en, wb_fwd_data, fwd_a_sel, fwd_b_sel, op1, op2);
        read_line;
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
