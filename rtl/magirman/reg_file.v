//=============================================================================
// reg_file.v
// 16 x 32-bit register file, r0-r13 general purpose, r14=sp, r15=ra.
// SimpleRisc does NOT hardwire r0 to zero (unlike MIPS/RISC-V).
//
// 2 combinational read ports, 1 synchronous write port. Write-first bypass
// on same-address same-cycle read/write (WB stage writing while ID stage
// reads the same register) -- this is separate from, and does NOT replace,
// the EX-stage forwarding_unit paths for distance 1 and 2 RAW hazards.
//=============================================================================
module reg_file (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [3:0]  rs1_addr,
  input  wire [3:0]  rs2_addr,
  input  wire [3:0]  rd_addr,
  input  wire [31:0] rd_data,
  input  wire        rd_write_en,
  output wire [31:0] rs1_data,
  output wire [31:0] rs2_data
);

  reg [31:0] regs [0:15];
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1)
        regs[i] <= 32'b0;
    end else if (rd_write_en) begin
      regs[rd_addr] <= rd_data;
    end
  end

  // Write-first same-cycle bypass
  assign rs1_data = (rd_write_en && (rd_addr == rs1_addr)) ? rd_data : regs[rs1_addr];
  assign rs2_data = (rd_write_en && (rd_addr == rs2_addr)) ? rd_data : regs[rs2_addr];

endmodule
