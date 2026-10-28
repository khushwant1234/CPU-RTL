`include "defines.vh"

module top_module #(parameter IMEM_DEPTH = 1024, parameter DMEM_DEPTH = 1024) (
    input clk,
    input rst_n,
    output [31:0] dbg_pc,
    output dbg_wb_en,
    output [3:0] dbg_wb_addr,
    output [31:0] dbg_wb_data,
    output dbg_stall,
    output dbg_flush
);

wire pc_stall, if_id_stall, if_id_flush, id_ex_flush, load_use;

wire [31:0] if_pc, if_instr, pc_next;
wire [31:0] id_pc, id_instr;
wire [3:0] id_rd_addr, id_rs1_addr, id_rs2_addr;
wire [31:0] id_imm_ext, id_rs1_data, id_rs2_data;
wire [26:0] id_branch_offset;
wire [`CTRL_W-1:0] id_ctrl;

wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm_ext;
wire [26:0] ex_branch_offset;
wire [3:0] ex_rd_addr, ex_rs1_addr, ex_rs2_addr;
wire [`CTRL_W-1:0] ex_ctrl;
wire [31:0] ex_op1, ex_op2, ex_alu_result;
wire [1:0] fwd_a_sel, fwd_b_sel;
wire flag_e, flag_gt;
wire ex_branch_taken;
wire [31:0] ex_branch_pc;

wire [31:0] mem_pc, mem_alu_result, mem_op2, mem_fwd_data, mem_ld_result;
wire [3:0] mem_rd_addr;
wire [`CTRL_W-1:0] mem_ctrl;
wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
wire dmem_we, dmem_re;

wire [31:0] wb_pc, wb_alu_result, wb_ld_result;
wire [3:0] wb_rd_addr;
wire [`CTRL_W-1:0] wb_ctrl;
wire wb_en;
wire [3:0] wb_addr;
wire [31:0] wb_data;

assign pc_next = ex_branch_taken ? ex_branch_pc : (if_pc + 4);

pc_reg u_pc(
    .clk(clk),
    .rst_n(rst_n),
    .pc_next(pc_next),
    .stall(pc_stall),
    .pc_out(if_pc)
);

instr_mem #(.DEPTH(IMEM_DEPTH)) u_imem(
    .addr(if_pc),
    .instr_out(if_instr)
);

if_id_reg u_if_id(
    .clk(clk),
    .rst_n(rst_n),
    .stall(if_id_stall),
    .flush(if_id_flush),
    .pc_in(if_pc),
    .instr_in(if_instr),
    .pc_out(id_pc),
    .instr_out(id_instr)
);

decoder u_decoder(
    .instr(id_instr),
    .rd_addr(id_rd_addr),
    .rs1_addr(id_rs1_addr),
    .rs2_addr(id_rs2_addr),
    .imm_ext(id_imm_ext),
    .branch_offset(id_branch_offset),
    .ctrl(id_ctrl)
);

reg_file u_reg_file(
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(id_rs1_addr),
    .rs2_addr(id_rs2_addr),
    .rd_addr(wb_addr),
    .rd_data(wb_data),
    .rd_write_en(wb_en),
    .rs1_data(id_rs1_data),
    .rs2_data(id_rs2_data)
);

id_ex_reg u_id_ex(
    .clk(clk),
    .rst_n(rst_n),
    .stall(1'b0),
    .flush(id_ex_flush),
    .pc_in(id_pc),
    .rs1_data_in(id_rs1_data),
    .rs2_data_in(id_rs2_data),
    .imm_ext_in(id_imm_ext),
    .branch_offset_in(id_branch_offset),
    .rd_addr_in(id_rd_addr),
    .rs1_addr_in(id_rs1_addr),
    .rs2_addr_in(id_rs2_addr),
    .ctrl_in(id_ctrl),
    .pc_out(ex_pc),
    .rs1_data_out(ex_rs1_data),
    .rs2_data_out(ex_rs2_data),
    .imm_ext_out(ex_imm_ext),
    .branch_offset_out(ex_branch_offset),
    .rd_addr_out(ex_rd_addr),
    .rs1_addr_out(ex_rs1_addr),
    .rs2_addr_out(ex_rs2_addr),
    .ctrl_out(ex_ctrl)
);

assign mem_fwd_data = mem_ctrl[`C_IS_CALL] ? (mem_pc + 4) : mem_alu_result;

forwarding_unit u_fwd(
    .ex_rs1_addr(ex_rs1_addr),
    .ex_rs2_addr(ex_rs2_addr),
    .ex_rs1_valid(ex_ctrl[`C_RS1_VALID]),
    .ex_rs2_valid(ex_ctrl[`C_RS2_VALID]),
    .ex_rs1_data(ex_rs1_data),
    .ex_rs2_data(ex_rs2_data),
    .mem_rd_addr(mem_rd_addr),
    .mem_reg_write_en(mem_ctrl[`C_REG_WRITE]),
    .mem_is_load(mem_ctrl[`C_MEM_READ]),
    .mem_fwd_data(mem_fwd_data),
    .wb_rd_addr(wb_addr),
    .wb_reg_write_en(wb_en),
    .wb_fwd_data(wb_data),
    .fwd_a_sel(fwd_a_sel),
    .fwd_b_sel(fwd_b_sel),
    .op1(ex_op1),
    .op2(ex_op2)
);

execute_stage u_ex(
    .clk(clk),
    .rst_n(rst_n),
    .pc(ex_pc),
    .op1(ex_op1),
    .op2(ex_op2),
    .imm_ext(ex_imm_ext),
    .branch_offset(ex_branch_offset),
    .ctrl(ex_ctrl),
    .alu_result(ex_alu_result),
    .flag_e(flag_e),
    .flag_gt(flag_gt),
    .branch_taken(ex_branch_taken),
    .branch_pc(ex_branch_pc)
);

hazard_unit u_hazard(
    .id_rs1_addr(id_rs1_addr),
    .id_rs2_addr(id_rs2_addr),
    .id_rs1_valid(id_ctrl[`C_RS1_VALID]),
    .id_rs2_valid(id_ctrl[`C_RS2_VALID]),
    .ex_mem_read_en(ex_ctrl[`C_MEM_READ]),
    .ex_rd_addr(ex_rd_addr),
    .branch_taken(ex_branch_taken),
    .load_use(load_use),
    .pc_stall(pc_stall),
    .if_id_stall(if_id_stall),
    .if_id_flush(if_id_flush),
    .id_ex_flush(id_ex_flush)
);

ex_mem_reg u_ex_mem(
    .clk(clk),
    .rst_n(rst_n),
    .pc_in(ex_pc),
    .alu_result_in(ex_alu_result),
    .op2_in(ex_op2),
    .rd_addr_in(ex_rd_addr),
    .ctrl_in(ex_ctrl),
    .pc_out(mem_pc),
    .alu_result_out(mem_alu_result),
    .op2_out(mem_op2),
    .rd_addr_out(mem_rd_addr),
    .ctrl_out(mem_ctrl)
);

memory_unit u_mem_unit(
    .ctrl(mem_ctrl),
    .alu_result(mem_alu_result),
    .op2(mem_op2),
    .mem_addr(dmem_addr),
    .mem_wdata(dmem_wdata),
    .mem_we(dmem_we),
    .mem_re(dmem_re),
    .mem_rdata(dmem_rdata),
    .ld_result(mem_ld_result)
);

memory_blackbox #(.DEPTH(DMEM_DEPTH)) u_dmem(
    .clk(clk),
    .we(dmem_we),
    .addr(dmem_addr),
    .wdata(dmem_wdata),
    .rdata(dmem_rdata)
);

mem_wb_reg u_mem_wb(
    .clk(clk),
    .rst_n(rst_n),
    .pc_in(mem_pc),
    .alu_result_in(mem_alu_result),
    .ld_result_in(mem_ld_result),
    .rd_addr_in(mem_rd_addr),
    .ctrl_in(mem_ctrl),
    .pc_out(wb_pc),
    .alu_result_out(wb_alu_result),
    .ld_result_out(wb_ld_result),
    .rd_addr_out(wb_rd_addr),
    .ctrl_out(wb_ctrl)
);

writeback u_wb(
    .pc(wb_pc),
    .alu_result(wb_alu_result),
    .ld_result(wb_ld_result),
    .rd_addr(wb_rd_addr),
    .ctrl(wb_ctrl),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .wb_en(wb_en)
);

assign dbg_pc = if_pc;
assign dbg_wb_en = wb_en;
assign dbg_wb_addr = wb_addr;
assign dbg_wb_data = wb_data;
assign dbg_stall = load_use;
assign dbg_flush = ex_branch_taken;

endmodule
