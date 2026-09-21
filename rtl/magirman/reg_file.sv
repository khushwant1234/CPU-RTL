//=============================================================================
// reg_file.sv
// 16 x 32-bit register file, r0-r13 general purpose, r14=sp, r15=ra.
// SimpleRisc does NOT hardwire r0 to zero (unlike MIPS/RISC-V) -- confirm
// against your course's canonical spec before assuming otherwise.
//
// 2 combinational read ports, 1 synchronous write port. Write-first bypass
// on same-address same-cycle read/write (WB stage writing while ID stage
// reads the same register) -- this is separate from, and does NOT replace,
// the EX-stage forwarding_unit paths needed for the pipeline-depth RAW
// hazards in the design doc (Sec 5.1 Cases A/B).
//=============================================================================
module reg_file (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [3:0]  rs1_addr,
  input  logic [3:0]  rs2_addr,
  input  logic [3:0]  rd_addr,
  input  logic [31:0] rd_data,
  input  logic        rd_write_en,
  output logic [31:0] rs1_data,
  output logic [31:0] rs2_data
);

  logic [31:0] regs [0:15];
  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i++)
        regs[i] <= 32'b0;
    end else if (rd_write_en) begin
      regs[rd_addr] <= rd_data;
    end
  end

  // Write-first same-cycle bypass
  assign rs1_data = (rd_write_en && (rd_addr == rs1_addr)) ? rd_data : regs[rs1_addr];
  assign rs2_data = (rd_write_en && (rd_addr == rs2_addr)) ? rd_data : regs[rs2_addr];

endmodule : reg_file
