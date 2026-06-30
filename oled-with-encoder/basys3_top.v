// basys3_top: SPI loader + POR + rotary encoder (input) + OLED SSD1306 I2C
//             (bit-bang via GPIO, open-drain) + LED.
//   datanw[0] -> SCL (open-drain),  datanw[1] -> SDA (open-drain)
//   pindata[0]=enc CLK, pindata[1]=enc DT   (encoder, utk ditampilkan ke OLED)
// Program (via SPI) men-decode encoder & menggambar angka ke OLED lewat I2C.
module basys3_top (
    input clk100, input btnC,
    input  enc_clk, input enc_dt,                 // rotary encoder
    output [7:0] led,                             // LED (debug)
    output oled_scl, output oled_sda,             // OLED I2C (open-drain)
    input spi_sclk, input spi_ceb, input spi_mosi, output spi_miso);

    // Power-On Reset
    reg [15:0] por_cnt=0; reg por_n=0;
    always @(posedge clk100) begin
        if(por_cnt!=16'hFFFF) begin por_cnt<=por_cnt+1; por_n<=0; end else por_n<=1;
    end
    wire rst_n = por_n & ~btnC;
    reg [5:0] divcnt=0; 
    
    always @(posedge clk100) divcnt<=divcnt+1; wire clk=divcnt[3];

    // sinkronisasi encoder -> pindata[0]=CLK, [1]=DT
    reg [1:0] sc=0, sd=0;
    always @(posedge clk) begin sc<={sc[0],enc_clk}; sd<={sd[0],enc_dt}; end
    wire [7:0] pindata = {6'b0, sd[1], sc[1]};

    wire trap; wire [11:0] dac; wire [7:0] gTx,gRx,gdat,gDSE; wire a,b,c;
    impl_axi u(.CLK(clk),.RST(rst_n),.trap(trap),
        .spi_axi_master_CEB(spi_ceb),.spi_axi_master_SCLK(spi_sclk),
        .spi_axi_master_DATA(spi_mosi),.spi_axi_master_DOUT(spi_miso),
        .DAC_interface_AXI_DATA(dac),.ADC_interface_AXI_BUSY(1'b0),.ADC_interface_AXI_DATA(10'd0),
        .completogpio_pindata(pindata),.completogpio_Rx(gRx),.completogpio_Tx(gTx),
        .completogpio_datanw(gdat),.completogpio_DSE(gDSE),
        .spi_axi_slave_CEB(a),.spi_axi_slave_SCLK(b),.spi_axi_slave_DATA(c));

    assign led = gdat;                            // debug: lihat aktivitas I2C di LED0/1

    // ---- I2C open-drain: datanw=1 -> lepas (high via pull-up), datanw=0 -> tarik low ----
    assign oled_scl = gdat[0] ? 1'bz : 1'b0;
    assign oled_sda = gdat[1] ? 1'bz : 1'b0;
endmodule