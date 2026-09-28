module hazard_unit(
    input [3:0] id_rs1_addr,
    input [3:0] id_rs2_addr,
    input id_rs1_valid,
    input id_rs2_valid,
    input ex_mem_read_en,
    input [3:0] ex_rd_addr,
    input branch_taken,
    output load_use,
    output pc_stall,
    output if_id_stall,
    output if_id_flush,
    output id_ex_flush
);

wire rs1_match;
wire rs2_match;

assign rs1_match = id_rs1_valid && (id_rs1_addr == ex_rd_addr);
assign rs2_match = id_rs2_valid && (id_rs2_addr == ex_rd_addr);

assign load_use = ex_mem_read_en && (rs1_match || rs2_match);

assign pc_stall = load_use && !branch_taken;
assign if_id_stall = load_use && !branch_taken;
assign if_id_flush = branch_taken;
assign id_ex_flush = branch_taken || load_use;

endmodule
