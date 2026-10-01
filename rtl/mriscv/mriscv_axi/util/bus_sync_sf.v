// bus_sync_sf.v - FPGA-safe rewrite (tanpa ~CLK)
// Setara fungsional dgn aslinya; semua FF posedge, tidak ada net-inverted clock.
`timescale 1ns/1ns
module bus_sync_sf #(
    parameter impl  = 0,   // 0: CLK1 > CLK2  1: CLK1 < CLK2
    parameter sword = 32
)(
    input              CLK1,
    input              CLK2,
    input              RST,
    input  [sword-1:0] data_in,
    output [sword-1:0] data_out
);

generate
  if (impl == 0) begin
    // CLK1 cepat (mis. CLK), CLK2 lambat (mis. SCLK)
    // Deteksi rising-edge CLK2 di domain CLK1 pakai 2-FF sync (posedge CLK1)
    // Saat tepi CLK2 terdeteksi, update data ke CLK2 domain.
    reg clk2_d1, clk2_d2, clk2_d3;
    wire clk2_rise_in_clk1;
    always @(posedge CLK1) begin
      if (!RST) begin clk2_d1<=0; clk2_d2<=0; clk2_d3<=0; end
      else      begin clk2_d1<=CLK2; clk2_d2<=clk2_d1; clk2_d3<=clk2_d2; end
    end
    assign clk2_rise_in_clk1 = clk2_d2 & ~clk2_d3;  // rising edge of CLK2 seen in CLK1 domain

    reg [sword-1:0] reg_data1, reg_data2, reg_data3;
    always @(posedge CLK1) begin
      if (!RST) begin reg_data1<=0; reg_data2<=0; end
      else begin
        reg_data1 <= data_in;
        if (clk2_rise_in_clk1) reg_data2 <= reg_data1;
      end
    end
    always @(posedge CLK2) begin
      if (!RST) reg_data3 <= 0;
      else      reg_data3 <= reg_data2;
    end
    assign data_out = reg_data3;

  end else begin
    // CLK1 lambat (mis. SCLK), CLK2 cepat (mis. CLK)
    // Deteksi rising-edge CLK1 di domain CLK2 pakai 2-FF sync (posedge CLK2)
    reg clk1_d1, clk1_d2, clk1_d3;
    wire clk1_rise_in_clk2;
    always @(posedge CLK2) begin
      if (!RST) begin clk1_d1<=0; clk1_d2<=0; clk1_d3<=0; end
      else      begin clk1_d1<=CLK1; clk1_d2<=clk1_d1; clk1_d3<=clk1_d2; end
    end
    assign clk1_rise_in_clk2 = clk1_d2 & ~clk1_d3;

    reg [sword-1:0] reg_data1, reg_data2, reg_data3;
    always @(posedge CLK1) begin
      if (!RST) reg_data1 <= 0;
      else      reg_data1 <= data_in;
    end
    always @(posedge CLK2) begin
      if (!RST) begin reg_data2<=0; reg_data3<=0; end
      else begin
        if (clk1_rise_in_clk2) reg_data2 <= reg_data1;
        reg_data3 <= reg_data2;
      end
    end
    assign data_out = reg_data3;

  end
endgenerate
endmodule
