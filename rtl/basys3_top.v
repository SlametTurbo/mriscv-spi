// =============================================================================
// basys3_top.v 
// Top-level TUNGGAL Basys3: SPI loader + UART + GPIO bank 1 (switch, LED,
// seven-segment) + GPIO bank 2 (rotary encoder + OLED SSD1306 I2C).
//   Bank 1 (byte 0x10040 + i*4): pindata = sw[7:0], datanw -> LED + 7-seg
//   Bank 2 (byte 0x100C0 + i*4): pindata[0]=enc CLK, [1]=enc DT
//                                datanw[0]=OLED SCL, [1]=OLED SDA (open-drain)
// Satu bitstream untuk semua firmware; ganti firmware cukup lewat SPI.
// =============================================================================
module basys3_top (
    input  clk100,
    input  btnC,
    input  [7:0] sw,
    output [7:0] led,
    output [6:0] seg,
    output       dp,
    output [3:0] an,
    input  spi_sclk, input spi_ceb, input spi_mosi, output spi_miso,
    output uart_txd,
    input  uart_rxd,
    input  enc_clk, input enc_dt,        // rotary encoder (enc_sw SENGAJA tidak disambung)
    output oled_scl, output oled_sda,    // OLED I2C open-drain (pull-up di XDC)
    output led_trap          // LD15: nyala = core trap (misaligned/ILLISN), latch sampai reset
);
    // Power-On Reset (~0.65 ms @ 100 MHz)
    reg [15:0] por_cnt = 0;
    reg        por_n   = 0;
    always @(posedge clk100) begin
        if (por_cnt != 16'hFFFF) begin por_cnt <= por_cnt + 1'b1; por_n <= 1'b0; end
        else por_n <= 1'b1;
    end

    // Clock /2: 100 MHz -> 50 MHz
    reg divcnt = 0;
    always @(posedge clk100) divcnt <= ~divcnt;
    wire clk = divcnt;

    // Sinkronizer reset 3-FF di domain clk. Dulu rst_n = por_n & ~btnC langsung
    // dipakai semua logika domain clk: por_n dari domain clk100 dan btnC mentah
    // (async) -> jalur cross-domain ~13 ns ke register file dll., pelepasan
    // reset bisa tidak serentak. Sekarang reset masuk/lepas sinkron ke clk;
    // rst_sync=0 saat konfigurasi, jadi reset tetap aktif sejak awal.
    reg [2:0] rst_sync = 3'b000;
    always @(posedge clk) rst_sync <= {rst_sync[1:0], por_n & ~btnC};
    wire rst_n = rst_sync[2];

    // Sinkronisasi switch (2-FF, hindari metastabil)
    reg [7:0] sw0 = 0, sw1 = 0;
    always @(posedge clk) begin sw0 <= sw; sw1 <= sw0; end
    wire [7:0] pindata = sw1;

    // Sinkronisasi encoder (2-FF) -> bank 2 pindata[0]=CLK, [1]=DT
    reg [1:0] ec0 = 0, ed0 = 0;
    always @(posedge clk) begin ec0 <= {ec0[0], enc_clk}; ed0 <= {ed0[0], enc_dt}; end
    wire [7:0] pindata2 = {6'b0, ed0[1], ec0[1]};
    wire [7:0] gpio2_datanw;

    wire trap;
    wire [11:0] dac_data;
    wire [7:0]  gpio_Tx, gpio_Rx, gpio_datanw, gpio_DSE;
    wire        sc, ss, sd;

    impl_axi u_impl (
        .CLK                    (clk),
        .RST                    (rst_n),
        .trap                   (trap),
        .spi_axi_master_CEB     (spi_ceb),
        .spi_axi_master_SCLK    (spi_sclk),
        .spi_axi_master_DATA    (spi_mosi),
        .spi_axi_master_DOUT    (spi_miso),
        .DAC_interface_AXI_DATA (dac_data),
        .ADC_interface_AXI_BUSY (1'b0),
        .ADC_interface_AXI_DATA (10'd0),
        .completogpio_pindata   (pindata),
        .completogpio_Rx        (gpio_Rx),
        .completogpio_Tx        (gpio_Tx),
        .completogpio_datanw    (gpio_datanw),
        .completogpio_DSE       (gpio_DSE),
        .spi_axi_slave_CEB      (sc),
        .spi_axi_slave_SCLK     (ss),
        .spi_axi_slave_DATA     (sd),
        .uart_tx_TXD            (uart_txd),
        .uart_rx_RXD            (uart_rxd),
        .completogpio2_pindata  (pindata2),
        .completogpio2_datanw   (gpio2_datanw)
    );

    // I2C open-drain: datanw=1 -> lepas (high lewat pull-up), datanw=0 -> tarik low
    assign oled_scl = gpio2_datanw[0] ? 1'bz : 1'b0;
    assign oled_sda = gpio2_datanw[1] ? 1'bz : 1'b0;

    assign led = gpio_datanw;

    // Indikator trap core. Tanpa ini "trap" dan "bus macet" terlihat identik
    // (dua-duanya cuma LED berhenti) -- bug .bss misaligned sempat lama salah
    // didiagnosis sebagai bug hardware karena ini (lihat CLAUDE.md, bagian UART).
    // Sengaja di LD15, bukan led[7], supaya tidak merebut LED GPIO firmware.
    assign led_trap = trap;

    // ---- Seven-segment: 2 digit hex dari byte gpio_datanw, time-multiplex ----
    wire [7:0] val = gpio_datanw;
    reg [16:0] scan_cnt = 0;
    always @(posedge clk100) scan_cnt <= scan_cnt + 1'b1;
    wire       digit_sel = scan_cnt[16];              // gantian ~1.3ms per digit
    wire [3:0] nibble = digit_sel ? val[7:4] : val[3:0];

    function [6:0] hex7seg;
        input [3:0] n;
        begin
            case (n)
                4'h0: hex7seg = 7'h3F; 4'h1: hex7seg = 7'h06;
                4'h2: hex7seg = 7'h5B; 4'h3: hex7seg = 7'h4F;
                4'h4: hex7seg = 7'h66; 4'h5: hex7seg = 7'h6D;
                4'h6: hex7seg = 7'h7D; 4'h7: hex7seg = 7'h07;
                4'h8: hex7seg = 7'h7F; 4'h9: hex7seg = 7'h6F;
                4'hA: hex7seg = 7'h77; 4'hB: hex7seg = 7'h7C;
                4'hC: hex7seg = 7'h39; 4'hD: hex7seg = 7'h5E;
                4'hE: hex7seg = 7'h79; 4'hF: hex7seg = 7'h71;
                default: hex7seg = 7'h00;
            endcase
        end
    endfunction

    assign seg = ~hex7seg(nibble);     // active-low segment
    assign dp  = 1'b1;                 // titik desimal selalu mati
    // an aktif-low; digit_sel=0 -> tampilkan an[0] (nibble rendah, val[3:0]),
    //               digit_sel=1 -> tampilkan an[1] (nibble tinggi, val[7:4])
    assign an  = digit_sel ? 4'b1101 : 4'b1110;

endmodule