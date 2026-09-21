//=============================================================================
// simplerisc_cpu.sv
// Top level of the 5-stage pipelined SimpleRisc processor.
//
//   IF  : pc_reg, instr_mem                          (Magirman)
//   OF  : if_id_reg, decoder, reg_file, id_ex_reg    (Magirman)
//   EX  : execute_stage (alu, flags, branch_unit)    (Khushwant)
//   MA  : ex_mem_reg, memory_unit, data_mem          (Khushwant / shared)
//   RW  : mem_wb_reg, writeback                      (Khushwant)
//   hazards : forwarding_unit, hazard_unit           (shared)
//
// Program is loaded by the testbench straight into u_imem.mem (and data
// into u_dmem.mem if needed). There is no halt instruction in SimpleRisc,
// tests end the program with "b ." (branch to itself) and the testbench
// watches for that.
//=============================================================================
module simplerisc_cpu
  import simpleriscprocessor_pkg::*;
#(
  parameter int IMEM_DEPTH = 1024,   // words
  parameter int DMEM_DEPTH = 1024    // words
)(
  input  logic        clk,
  input  logic        rst_n,

  // debug / observation ports (used by the testbench, handy in waveforms)
  output logic [31:0] dbg_pc,          // pc in IF
  output logic        dbg_wb_en,
  output logic [3:0]  dbg_wb_addr,
  output logic [31:0] dbg_wb_data,
  output logic        dbg_stall,       // load-use stall this cycle
  output logic        dbg_flush        // taken branch this cycle
);

  // =====================================================================
  // Hazard control
  // =====================================================================
  logic pc_stall, if_id_stall, if_id_flush, id_ex_flush, load_use;

  // =====================================================================
  // IF
  // =====================================================================
  logic [31:0] if_pc, if_instr, pc_next;
  logic        ex_branch_taken;
  logic [31:0] ex_branch_pc;

  assign pc_next = ex_branch_taken ? ex_branch_pc : (if_pc + 32'd4);

  pc_reg u_pc (
    .clk     (clk),
    .rst_n   (rst_n),
    .pc_next (pc_next),
    .stall   (pc_stall),
    .pc_out  (if_pc)
  );

  instr_mem #(.DEPTH(IMEM_DEPTH)) u_imem (
    .addr      (if_pc),
    .instr_out (if_instr)
  );

  logic [31:0] id_pc, id_instr;

  if_id_reg u_if_id (
    .clk       (clk),
    .rst_n     (rst_n),
    .stall     (if_id_stall),
    .flush     (if_id_flush),
    .pc_in     (if_pc),
    .instr_in  (if_instr),
    .pc_out    (id_pc),
    .instr_out (id_instr)
  );

  // =====================================================================
  // OF (decode + register read)
  // =====================================================================
  logic [3:0]  id_rd_addr, id_rs1_addr, id_rs2_addr;
  logic [31:0] id_imm_ext, id_rs1_data, id_rs2_data;
  logic [26:0] id_branch_offset;
  ctrl_t       id_ctrl;

  // write-back port (driven in RW)
  logic        wb_en;
  logic [3:0]  wb_addr;
  logic [31:0] wb_data;

  decoder u_decoder (
    .instr         (id_instr),
    .rd_addr       (id_rd_addr),
    .rs1_addr      (id_rs1_addr),
    .rs2_addr      (id_rs2_addr),
    .imm_ext       (id_imm_ext),
    .branch_offset (id_branch_offset),
    .ctrl          (id_ctrl)
  );

  reg_file u_reg_file (
    .clk         (clk),
    .rst_n       (rst_n),
    .rs1_addr    (id_rs1_addr),
    .rs2_addr    (id_rs2_addr),
    .rd_addr     (wb_addr),
    .rd_data     (wb_data),
    .rd_write_en (wb_en),
    .rs1_data    (id_rs1_data),
    .rs2_data    (id_rs2_data)
  );

  logic [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm_ext;
  logic [26:0] ex_branch_offset;
  logic [3:0]  ex_rd_addr, ex_rs1_addr, ex_rs2_addr;
  ctrl_t       ex_ctrl;

  // ID/EX never has to hold: on a load-use stall the instruction stays in
  // IF/ID and a bubble goes into ID/EX instead.
  id_ex_reg u_id_ex (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall             (1'b0),
    .flush             (id_ex_flush),
    .pc_in             (id_pc),
    .rs1_data_in       (id_rs1_data),
    .rs2_data_in       (id_rs2_data),
    .imm_ext_in        (id_imm_ext),
    .branch_offset_in  (id_branch_offset),
    .rd_addr_in        (id_rd_addr),
    .rs1_addr_in       (id_rs1_addr),
    .rs2_addr_in       (id_rs2_addr),
    .ctrl_in           (id_ctrl),
    .pc_out            (ex_pc),
    .rs1_data_out      (ex_rs1_data),
    .rs2_data_out      (ex_rs2_data),
    .imm_ext_out       (ex_imm_ext),
    .branch_offset_out (ex_branch_offset),
    .rd_addr_out       (ex_rd_addr),
    .rs1_addr_out      (ex_rs1_addr),
    .rs2_addr_out      (ex_rs2_addr),
    .ctrl_out          (ex_ctrl)
  );

  // =====================================================================
  // EX
  // =====================================================================
  logic [31:0] mem_pc, mem_alu_result, mem_op2;
  logic [3:0]  mem_rd_addr;
  ctrl_t       mem_ctrl;
  logic [31:0] mem_fwd_data;

  // value the instruction in MEM will write back (call writes pc+4, not the
  // ALU output). Loads are never forwarded from here (see forwarding_unit).
  assign mem_fwd_data = mem_ctrl.is_call ? (mem_pc + 32'd4) : mem_alu_result;

  logic [31:0] ex_op1, ex_op2;
  fwd_sel_e    fwd_a_sel, fwd_b_sel;

  forwarding_unit u_fwd (
    .ex_rs1_addr      (ex_rs1_addr),
    .ex_rs2_addr      (ex_rs2_addr),
    .ex_rs1_valid     (ex_ctrl.rs1_valid),
    .ex_rs2_valid     (ex_ctrl.rs2_valid),
    .ex_rs1_data      (ex_rs1_data),
    .ex_rs2_data      (ex_rs2_data),
    .mem_rd_addr      (mem_rd_addr),
    .mem_reg_write_en (mem_ctrl.reg_write_en),
    .mem_is_load      (mem_ctrl.mem_read_en),
    .mem_fwd_data     (mem_fwd_data),
    .wb_rd_addr       (wb_addr),
    .wb_reg_write_en  (wb_en),
    .wb_fwd_data      (wb_data),
    .fwd_a_sel        (fwd_a_sel),
    .fwd_b_sel        (fwd_b_sel),
    .op1              (ex_op1),
    .op2              (ex_op2)
  );

  logic [31:0] ex_alu_result;
  logic        flag_e, flag_gt;

  execute_stage u_ex (
    .clk           (clk),
    .rst_n         (rst_n),
    .pc            (ex_pc),
    .op1           (ex_op1),
    .op2           (ex_op2),
    .imm_ext       (ex_imm_ext),
    .branch_offset (ex_branch_offset),
    .ctrl          (ex_ctrl),
    .alu_result    (ex_alu_result),
    .flag_e        (flag_e),
    .flag_gt       (flag_gt),
    .branch_taken  (ex_branch_taken),
    .branch_pc     (ex_branch_pc)
  );

  hazard_unit u_hazard (
    .id_rs1_addr    (id_rs1_addr),
    .id_rs2_addr    (id_rs2_addr),
    .id_rs1_valid   (id_ctrl.rs1_valid),
    .id_rs2_valid   (id_ctrl.rs2_valid),
    .ex_mem_read_en (ex_ctrl.mem_read_en),
    .ex_rd_addr     (ex_rd_addr),
    .branch_taken   (ex_branch_taken),
    .load_use       (load_use),
    .pc_stall       (pc_stall),
    .if_id_stall    (if_id_stall),
    .if_id_flush    (if_id_flush),
    .id_ex_flush    (id_ex_flush)
  );

  ex_mem_reg u_ex_mem (
    .clk            (clk),
    .rst_n          (rst_n),
    .pc_in          (ex_pc),
    .alu_result_in  (ex_alu_result),
    .op2_in         (ex_op2),          // forwarded store data
    .rd_addr_in     (ex_rd_addr),
    .ctrl_in        (ex_ctrl),
    .pc_out         (mem_pc),
    .alu_result_out (mem_alu_result),
    .op2_out        (mem_op2),
    .rd_addr_out    (mem_rd_addr),
    .ctrl_out       (mem_ctrl)
  );

  // =====================================================================
  // MA
  // =====================================================================
  logic [31:0] dmem_addr, dmem_wdata, dmem_rdata, mem_ld_result;
  logic        dmem_we, dmem_re;

  memory_unit u_mem_unit (
    .ctrl       (mem_ctrl),
    .alu_result (mem_alu_result),
    .op2        (mem_op2),
    .mem_addr   (dmem_addr),
    .mem_wdata  (dmem_wdata),
    .mem_we     (dmem_we),
    .mem_re     (dmem_re),
    .mem_rdata  (dmem_rdata),
    .ld_result  (mem_ld_result)
  );

  data_mem #(.DEPTH(DMEM_DEPTH)) u_dmem (
    .clk   (clk),
    .we    (dmem_we),
    .addr  (dmem_addr),
    .wdata (dmem_wdata),
    .rdata (dmem_rdata)
  );

  logic [31:0] wb_pc, wb_alu_result, wb_ld_result;
  logic [3:0]  wb_rd_addr;
  ctrl_t       wb_ctrl;

  mem_wb_reg u_mem_wb (
    .clk            (clk),
    .rst_n          (rst_n),
    .pc_in          (mem_pc),
    .alu_result_in  (mem_alu_result),
    .ld_result_in   (mem_ld_result),
    .rd_addr_in     (mem_rd_addr),
    .ctrl_in        (mem_ctrl),
    .pc_out         (wb_pc),
    .alu_result_out (wb_alu_result),
    .ld_result_out  (wb_ld_result),
    .rd_addr_out    (wb_rd_addr),
    .ctrl_out       (wb_ctrl)
  );

  // =====================================================================
  // RW
  // =====================================================================
  writeback u_wb (
    .pc         (wb_pc),
    .alu_result (wb_alu_result),
    .ld_result  (wb_ld_result),
    .rd_addr    (wb_rd_addr),
    .ctrl       (wb_ctrl),
    .wb_addr    (wb_addr),
    .wb_data    (wb_data),
    .wb_en      (wb_en)
  );

  // =====================================================================
  // Debug
  // =====================================================================
  assign dbg_pc      = if_pc;
  assign dbg_wb_en   = wb_en;
  assign dbg_wb_addr = wb_addr;
  assign dbg_wb_data = wb_data;
  assign dbg_stall   = load_use;
  assign dbg_flush   = ex_branch_taken;

endmodule : simplerisc_cpu
