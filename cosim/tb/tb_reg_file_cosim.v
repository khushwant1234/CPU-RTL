`timescale 1ns/1ps

module tb_reg_file_cosim;

reg clk = 0;
reg rst_n = 1;
reg rd_write_en;
reg [3:0] rd_addr, rs1_addr, rs2_addr;
reg [31:0] rd_data;
wire [31:0] rs1_data, rs2_data;

integer in, out, r, done;

reg_file dut(
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .rd_write_en(rd_write_en),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

always #5 clk = ~clk;

initial begin
    in = $fopen("reg_file.vec", "r");
    out = $fopen("reg_file.rtl", "w");
    if (in == 0) begin
        $display("cannot open reg_file.vec");
        $finish;
    end

    rd_write_en = 0;
    #1 rst_n = 0;
    #1 rst_n = 1;

    done = 0;
    while (!done) begin
        @(negedge clk);
        r = $fscanf(in, "%h %h %h %h %h %h\n", rst_n, rd_write_en, rd_addr, rd_data, rs1_addr, rs2_addr);
        if (r == 6) begin
            #1;
            $fdisplay(out, "rst_n=%h we=%h wa=%h wd=%h rs1=%h rs2=%h -> d1=%h d2=%h",
                      rst_n, rd_write_en, rd_addr, rd_data, rs1_addr, rs2_addr, rs1_data, rs2_data);
        end
        else
            done = 1;
    end

    $fclose(in);
    $fclose(out);
    $finish;
end

endmodule
