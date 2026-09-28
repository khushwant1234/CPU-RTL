`include "defines.vh"

module forwarding_unit(
    input [3:0] ex_rs1_addr,
    input [3:0] ex_rs2_addr,
    input ex_rs1_valid,
    input ex_rs2_valid,
    input [31:0] ex_rs1_data,
    input [31:0] ex_rs2_data,
    input [3:0] mem_rd_addr,
    input mem_reg_write_en,
    input mem_is_load,
    input [31:0] mem_fwd_data,
    input [3:0] wb_rd_addr,
    input wb_reg_write_en,
    input [31:0] wb_fwd_data,
    output reg [1:0] fwd_a_sel,
    output reg [1:0] fwd_b_sel,
    output reg [31:0] op1,
    output reg [31:0] op2
);

always @(*) begin
    if (ex_rs1_valid && mem_reg_write_en && !mem_is_load && mem_rd_addr == ex_rs1_addr)
        fwd_a_sel = `FWD_EX_MEM;
    else if (ex_rs1_valid && wb_reg_write_en && wb_rd_addr == ex_rs1_addr)
        fwd_a_sel = `FWD_MEM_WB;
    else
        fwd_a_sel = `FWD_NONE;

    if (ex_rs2_valid && mem_reg_write_en && !mem_is_load && mem_rd_addr == ex_rs2_addr)
        fwd_b_sel = `FWD_EX_MEM;
    else if (ex_rs2_valid && wb_reg_write_en && wb_rd_addr == ex_rs2_addr)
        fwd_b_sel = `FWD_MEM_WB;
    else
        fwd_b_sel = `FWD_NONE;
end

always @(*) begin
    if (fwd_a_sel == `FWD_EX_MEM)
        op1 = mem_fwd_data;
    else if (fwd_a_sel == `FWD_MEM_WB)
        op1 = wb_fwd_data;
    else
        op1 = ex_rs1_data;

    if (fwd_b_sel == `FWD_EX_MEM)
        op2 = mem_fwd_data;
    else if (fwd_b_sel == `FWD_MEM_WB)
        op2 = wb_fwd_data;
    else
        op2 = ex_rs2_data;
end

endmodule
