//=============================================================================
// forwarding_unit.v
// Resolves RAW data hazards for the instruction in EX by bypassing results
// that have not been written to the register file yet.
//
//   Case A (distance 1): producer is in MEM  -> take EX/MEM result
//   Case B (distance 2): producer is in WB   -> take MEM/WB write-back data
//   distance 3+       : reg_file write-first bypass already covers it
//
// EX/MEM wins over MEM/WB when both match, since it is the newer value.
//
// Only compares against sources the instruction really reads
// (rs1_valid/rs2_valid from the decoder), so immediates that happen to look
// like a register number in the rs2 field never trigger a false forward.
// That also covers st (stored reg is on rs2) and ret (reads r15 on rs1)
// without any special cases here.
//
// A load in MEM is never forwarded from EX/MEM: its data is not ready yet.
// hazard_unit stalls one cycle for that case (load-use), after which the
// load is in WB and Case B picks it up.
//=============================================================================
`include "defines.vh"

module forwarding_unit (
  // instruction in EX (from ID/EX)
  input  wire [3:0]  ex_rs1_addr,
  input  wire [3:0]  ex_rs2_addr,
  input  wire        ex_rs1_valid,
  input  wire        ex_rs2_valid,
  input  wire [31:0] ex_rs1_data,     // value read in ID
  input  wire [31:0] ex_rs2_data,

  // instruction in MEM (from EX/MEM)
  input  wire [3:0]  mem_rd_addr,
  input  wire        mem_reg_write_en,
  input  wire        mem_is_load,
  input  wire [31:0] mem_fwd_data,    // alu result, or pc+4 for call

  // instruction in WB (from MEM/WB)
  input  wire [3:0]  wb_rd_addr,
  input  wire        wb_reg_write_en,
  input  wire [31:0] wb_fwd_data,     // final write-back value

  output reg  [1:0]  fwd_a_sel,       // FWD_* in defines.vh
  output reg  [1:0]  fwd_b_sel,
  output reg  [31:0] op1,
  output reg  [31:0] op2
);

  wire a_mem_hit = ex_rs1_valid && mem_reg_write_en && !mem_is_load && (mem_rd_addr == ex_rs1_addr);
  wire a_wb_hit  = ex_rs1_valid && wb_reg_write_en  && (wb_rd_addr == ex_rs1_addr);
  wire b_mem_hit = ex_rs2_valid && mem_reg_write_en && !mem_is_load && (mem_rd_addr == ex_rs2_addr);
  wire b_wb_hit  = ex_rs2_valid && wb_reg_write_en  && (wb_rd_addr == ex_rs2_addr);

  always @(*) begin
    if      (a_mem_hit) fwd_a_sel = `FWD_EX_MEM;
    else if (a_wb_hit)  fwd_a_sel = `FWD_MEM_WB;
    else                fwd_a_sel = `FWD_NONE;

    if      (b_mem_hit) fwd_b_sel = `FWD_EX_MEM;
    else if (b_wb_hit)  fwd_b_sel = `FWD_MEM_WB;
    else                fwd_b_sel = `FWD_NONE;
  end

  always @(*) begin
    case (fwd_a_sel)
      `FWD_EX_MEM: op1 = mem_fwd_data;
      `FWD_MEM_WB: op1 = wb_fwd_data;
      default:     op1 = ex_rs1_data;
    endcase
    case (fwd_b_sel)
      `FWD_EX_MEM: op2 = mem_fwd_data;
      `FWD_MEM_WB: op2 = wb_fwd_data;
      default:     op2 = ex_rs2_data;
    endcase
  end

endmodule
