// basys3_top: SPI loader + Power-On Reset + rotary encoder (input) +
//             seven-segment (hardware hex decode) + LED.
//
// Rotary encoder KY-040 -> GPIO input (pindata):
//   pindata[0] = CLK (A),  pindata[1] = DT (B),  pindata[2] = SW (tombol)
// Program (di-upload via SPI) men-decode kuadratur di software, lalu menulis
// nilai counter ke GPIO output (datanw) -> tampil di seven-seg & LED.
module basys3_top (
    input clk100, input btnC,
    input  enc_clk, input enc_dt, input enc_sw,   // rotary encoder
    output [7:0] led,                             // LED onboard
    output [6:0] seg, output dp, output [3:0] an,  // seven-segment
    input spi_sclk, input spi_ceb, input spi_mosi, output spi_miso);

    // ---- Power-On Reset otomatis (tanpa perlu tekan btnC) ----
    reg [15:0] por_cnt = 16'd0;
    reg        por_n   = 1'b0;
    always @(posedge clk100) begin
        if (por_cnt != 16'hFFFF) begin por_cnt <= por_cnt + 1'b1; por_n <= 1'b0; end
        else por_n <= 1'b1;
    end
    wire rst_n = por_n & ~btnC;

    reg [5:0] divcnt = 6'b000000;
    always @(posedge clk100) divcnt <= divcnt + 1'b1;
    wire clk = divcnt[5];     // /64 ~1.5MHz

    // ---- sinkronisasi input encoder (2 FF) untuk hindari metastabil ----
    reg [1:0] s_clk=0, s_dt=0, s_sw=0;
    always @(posedge clk) begin
        s_clk <= {s_clk[0], enc_clk};
        s_dt  <= {s_dt[0],  enc_dt};
        s_sw  <= {s_sw[0],  enc_sw};
    end
    // pindata[0]=CLK, [1]=DT, [2]=SW (sisanya 0)
    wire [7:0] pindata = {5'b0, s_sw[1], s_dt[1], s_clk[1]};

    wire trap; wire [11:0] dac_data;
    wire [7:0] gpio_Tx, gpio_Rx, gpio_datanw, gpio_DSE; wire sc, ss, sd;
    impl_axi u_impl (
        .CLK(clk), .RST(rst_n), .trap(trap),
        .spi_axi_master_CEB(spi_ceb), .spi_axi_master_SCLK(spi_sclk),
        .spi_axi_master_DATA(spi_mosi), .spi_axi_master_DOUT(spi_miso),
        .DAC_interface_AXI_DATA(dac_data),
        .ADC_interface_AXI_BUSY(1'b0), .ADC_interface_AXI_DATA(10'd0),
        .completogpio_pindata(pindata),            // <-- encoder masuk GPIO input
        .completogpio_Rx(gpio_Rx), .completogpio_Tx(gpio_Tx),
        .completogpio_datanw(gpio_datanw), .completogpio_DSE(gpio_DSE),
        .spi_axi_slave_CEB(sc), .spi_axi_slave_SCLK(ss), .spi_axi_slave_DATA(sd));

    assign led = gpio_datanw;                      // nilai counter -> LED

    // ---- seven-segment: tampilkan gpio_datanw sbg 2 digit hex ----
    wire [7:0] val = gpio_datanw;
    reg [16:0] refcnt = 0;
    always @(posedge clk100) refcnt <= refcnt + 1'b1;
    wire digsel = refcnt[16];
    wire [3:0] nib = digsel ? val[7:4] : val[3:0];
    function [6:0] hex7; input [3:0] n; begin
        case (n)
            4'h0:hex7=7'h3F;4'h1:hex7=7'h06;4'h2:hex7=7'h5B;4'h3:hex7=7'h4F;
            4'h4:hex7=7'h66;4'h5:hex7=7'h6D;4'h6:hex7=7'h7D;4'h7:hex7=7'h07;
            4'h8:hex7=7'h7F;4'h9:hex7=7'h6F;4'hA:hex7=7'h77;4'hB:hex7=7'h7C;
            4'hC:hex7=7'h39;4'hD:hex7=7'h5E;4'hE:hex7=7'h79;4'hF:hex7=7'h71;
            default:hex7=7'h00;
        endcase
    end endfunction
    assign seg = ~hex7(nib);          // active-low
    assign dp  = 1'b1;                 // titik mati
    assign an  = digsel ? 4'b1101 : 4'b1110;
endmodule