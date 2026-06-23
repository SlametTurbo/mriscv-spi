// basys3_top: SPI loader + Power-On Reset + LED + INPUT switch + 7-Segment.
module basys3_top (
    input        clk100,      // Clock utama 100MHz
    input        btnC,        // Tombol reset manual
    input  [7:0] sw,          // 8 slide switch onboard -> input GPIO
    output [7:0] led,         // 8 LED onboard <- output GPIO
    output [6:0] seg,         // 7-segment CA..CG (active-low)
    output       dp,          // 7-segment decimal point
    output [3:0] an,          // 7-segment anoda (active-low)
    input        spi_sclk,    // SPI Loader clock
    input        spi_ceb,     // SPI Loader chip enable
    input        spi_mosi,    // SPI Loader data masuk
    output       spi_miso     // SPI Loader data keluar
);

    // ---- Power-On Reset otomatis (tanpa perlu tekan btnC) ----
    reg [15:0] por_cnt = 16'd0;
    reg        por_n   = 1'b0;
    
    always @(posedge clk100) begin
        if (por_cnt != 16'hFFFF) begin 
            por_cnt <= por_cnt + 1'b1; 
            por_n <= 1'b0; 
        end else begin
            por_n <= 1'b1;
        end
    end
    wire rst_n = por_n & ~btnC;

    // ---- Pembagi Clock untuk CPU ----
    reg [5:0] divcnt = 6'b000000;
    always @(posedge clk100) divcnt <= divcnt + 1'b1;
    wire clk = divcnt[5];     // /64 ~1.5MHz; SCLK <= ~200kHz

    // ---- Sistem AXI (u_impl) ----
    wire trap; 
    wire [11:0] dac_data;
    wire [7:0] gpio_Tx, gpio_Rx, gpio_datanw, gpio_DSE; 
    wire sc, ss, sd;
    
    impl_axi u_impl (
        .CLK(clk), 
        .RST(rst_n), 
        .trap(trap),
        // Koneksi SPI Loader (Master)
        .spi_axi_master_CEB(spi_ceb), 
        .spi_axi_master_SCLK(spi_sclk),
        .spi_axi_master_DATA(spi_mosi), 
        .spi_axi_master_DOUT(spi_miso),
        // DAC/ADC Dummy
        .DAC_interface_AXI_DATA(dac_data),
        .ADC_interface_AXI_BUSY(1'b0), 
        .ADC_interface_AXI_DATA(10'd0),
        // Koneksi GPIO Mapped
        .completogpio_pindata(sw),                  // INPUT: Switch diteruskan ke GPIO
        .completogpio_Rx(gpio_Rx), 
        .completogpio_Tx(gpio_Tx),
        .completogpio_datanw(gpio_datanw),          // OUTPUT: Hasil eksekusi CPU
        .completogpio_DSE(gpio_DSE),
        // SPI Slave Dummy
        .spi_axi_slave_CEB(sc), 
        .spi_axi_slave_SCLK(ss), 
        .spi_axi_slave_DATA(sd)
    );

    // ---- Koneksi Output LED ----
    assign led = gpio_datanw;                       // Output GPIO memetakan nilai langsung ke LED

    // ---- Logika Multiplexing & Dekoder Seven-Segment ----
    wire [7:0] val = gpio_datanw;                   // CPU output digunakan sebagai input untuk ditranslasikan

    reg [16:0] refcnt = 0;                          // Multiplexing refresh rate ~763 Hz
    always @(posedge clk100) refcnt <= refcnt + 1'b1;
    wire digsel = refcnt[16];

    wire [3:0] nib = digsel ? val[7:4] : val[3:0];  // Pemilihan nibble atas / bawah bergantian

    // Fungsi konversi 4-bit ke 7-Segment (Hexadecimal)
    function [6:0] hex7; 
        input [3:0] n; 
        begin
            case (n)
                4'h0: hex7=7'h3F; 4'h1: hex7=7'h06; 4'h2: hex7=7'h5B; 4'h3: hex7=7'h4F;
                4'h4: hex7=7'h66; 4'h5: hex7=7'h6D; 4'h6: hex7=7'h7D; 4'h7: hex7=7'h07;
                4'h8: hex7=7'h7F; 4'h9: hex7=7'h6F; 4'hA: hex7=7'h77; 4'hB: hex7=7'h7C;
                4'hC: hex7=7'h39; 4'hD: hex7=7'h5E; 4'hE: hex7=7'h79; 4'hF: hex7=7'h71;
                default: hex7=7'h00;
            endcase
        end 
    endfunction

    // Penetapan sinyal display
    assign seg = ~hex7(nib);                        // Dibalik karena display bersifat active-low
    assign dp  = 1'b1;                              // Mematikan decimal point (1 = off pada active-low)
    assign an  = digsel ? 4'b1101 : 4'b1110;        // Bergantian menyalakan AN1 (hi nibble) dan AN0 (lo nibble)

endmodule