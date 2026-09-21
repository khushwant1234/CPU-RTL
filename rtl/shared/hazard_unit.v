//=============================================================================
// hazard_unit.v
// Stall / flush control for the 5-stage pipeline.
//
// 1) Load-use hazard (data):
//      ld  r1, 0[r2]      <- in EX
//      add r3, r1, r4     <- in ID, needs r1 next cycle but ld data only
//                            exists at the end of MEM
//    -> freeze PC and IF/ID for one cycle and put a bubble into ID/EX.
//       Next cycle the ld is in WB and forwarding_unit (MEM/WB path)
//       supplies the value.
//
// 2) Taken branch (control): b/call/ret/beq/bgt resolve in EX. The two
//    younger instructions already fetched (in IF/ID and ID/EX) are on the
//    wrong path -> flush both, PC loads branch_pc. Penalty = 2 cycles.
//
// A taken branch in EX and a load-use can't really happen together (the
// instruction in EX would have to be both a load and a branch), but if it
// ever did the branch wins: the instruction in ID is flushed anyway so
// stalling it would be pointless.
//=============================================================================
module hazard_unit (
  // instruction in ID (decoder outputs)
  input  wire [3:0] id_rs1_addr,
  input  wire [3:0] id_rs2_addr,
  input  wire       id_rs1_valid,
  input  wire       id_rs2_valid,

  // instruction in EX (ID/EX)
  input  wire       ex_mem_read_en,
  input  wire [3:0] ex_rd_addr,

  // branch resolution in EX
  input  wire       branch_taken,

  output wire       load_use,      // exported for debug / perf counting
  output wire       pc_stall,
  output wire       if_id_stall,
  output wire       if_id_flush,
  output wire       id_ex_flush
);

  assign load_use = ex_mem_read_en &&
                    ((id_rs1_valid && (id_rs1_addr == ex_rd_addr)) ||
                     (id_rs2_valid && (id_rs2_addr == ex_rd_addr)));

  assign pc_stall    = load_use && !branch_taken;
  assign if_id_stall = load_use && !branch_taken;
  assign if_id_flush = branch_taken;
  assign id_ex_flush = branch_taken || load_use;

endmodule
