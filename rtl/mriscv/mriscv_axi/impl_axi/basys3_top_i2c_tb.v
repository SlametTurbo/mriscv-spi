// basys3_top_i2c_tb.v -- uji SoC penuh I2C master hardware (firmware i2c_test).
// Cara pakai: make build FW=i2c_test -> .bin jadi good.hex (lihat impl_axi_busrst_tb.v),
// iverilog -g2012 -s tb <tb ini> + semua .v non-tb (sama dgn Makefile), vvp.
// Slave dummy alamat 0x3C di tb; LED=0x5A kalau semua urutan benar, 0xEE kalau salah.
`timescale 1ns/1ps
module tb;
    reg clk100 = 0; always #5 clk100 = ~clk100;
    reg btnC = 0, spi_ceb = 1, spi_sclk = 0, spi_mosi = 0, enc_clk = 1, enc_dt = 1;
    reg [7:0] sw = 0;
    wire [7:0] led; wire [6:0] seg; wire dp; wire [3:0] an;
    wire spi_miso, uart_txd, led_trap, oled_scl, oled_sda;
    pullup (oled_scl); pullup (oled_sda);
    basys3_top dut(.clk100(clk100), .btnC(btnC), .sw(sw), .led(led), .seg(seg), .dp(dp), .an(an),
        .spi_sclk(spi_sclk), .spi_ceb(spi_ceb), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .uart_txd(uart_txd), .uart_rxd(1'b1), .enc_clk(enc_clk), .enc_dt(enc_dt),
        .oled_scl(oled_scl), .oled_sda(oled_sda), .led_trap(led_trap));

    task spi_frame(input [1:0] instr, input [31:0] addr, input [31:0] data);
        reg [65:0] f; integer k;
        begin
            f = {instr, addr, data};
            spi_ceb = 0; repeat (16) @(posedge clk100);
            for (k = 65; k >= 0; k = k - 1) begin
                spi_mosi = f[k]; repeat (8) @(posedge clk100);
                spi_sclk = 1;    repeat (8) @(posedge clk100);
                spi_sclk = 0;
            end
            repeat (8) @(posedge clk100); spi_ceb = 1; repeat (32) @(posedge clk100);
        end
    endtask

    // ---------------- model slave ----------------
    reg sda_s_o = 1, stretch = 0;
    assign oled_sda = sda_s_o ? 1'bz : 1'b0;
    assign oled_scl = stretch ? 1'b0 : 1'bz;
    reg start_p = 0, stop_p = 0;
    reg [7:0] got [0:15]; integer ngot = 0;
    integer nstop = 0, nstart = 0;
    reg [7:0] rdtab [0:3];
    integer rdi = 0;
    initial begin rdtab[0]=8'hA5; rdtab[1]=8'h5A; rdtab[2]=8'hC3; rdtab[3]=8'h3C; end

    always @(negedge oled_sda) if (oled_scl === 1'b1) begin
        nstart = nstart + 1; start_p = 1; #1 start_p = 0;
    end
    always @(posedge oled_sda) if (oled_scl === 1'b1) begin
        nstop = nstop + 1; stop_p = 1; #1 stop_p = 0;
    end

    reg [7:0] b; reg aborted; integer i;
    task recv_byte;
    begin
        aborted = 0; b = 0;
        for (i = 0; i < 8 && !aborted; i = i + 1) begin
            @(posedge oled_scl or posedge stop_p or posedge start_p);
            if (stop_p || start_p) aborted = 1;
            else b = {b[6:0], oled_sda};
        end
    end
    endtask

    reg rw, nack_m, restart;
    initial begin
        forever begin
            @(posedge start_p);
            restart = 1;
            while (restart) begin
                restart = 0;
                recv_byte;
                if (aborted) begin
                    if (start_p) restart = 1;
                end else if (b[7:1] != 7'h3C) begin
                    // alamat salah: tidak ACK, tunggu stop/start
                    @(negedge oled_scl);
                    @(posedge stop_p or posedge start_p);
                    if (start_p) restart = 1;
                end else begin
                    rw = b[0];
                    @(negedge oled_scl);
                    stretch = 1; sda_s_o = 0;           // ACK + tahan SCL
                    #2000 stretch = 0;
                    @(posedge oled_scl); @(negedge oled_scl);
                    if (!rw) begin
                        sda_s_o = 1;
                        aborted = 0;
                        got[ngot] = b; ngot = ngot + 1;
                        while (!aborted) begin
                            recv_byte;
                            if (aborted) begin if (start_p) restart = 1; end
                            else begin
                                got[ngot] = b; ngot = ngot + 1;
                                @(negedge oled_scl); sda_s_o = 0;       // ACK
                                @(posedge oled_scl); @(negedge oled_scl); sda_s_o = 1;
                            end
                        end
                    end else begin
                        got[ngot] = b; ngot = ngot + 1;
                        nack_m = 0;
                        while (!nack_m) begin
                            b = rdtab[rdi & 3]; rdi = rdi + 1;
                            for (i = 7; i >= 0; i = i - 1) begin
                                sda_s_o = b[i];
                                @(posedge oled_scl); @(negedge oled_scl);
                            end
                            sda_s_o = 1;
                            @(posedge oled_scl); nack_m = oled_sda; @(negedge oled_scl);
                        end
                    end
                end
            end
        end
    end

    integer fails = 0, k2;
    reg [31:0] img [0:2047];
    initial begin
        for (k2 = 0; k2 < 2048; k2 = k2 + 1) img[k2] = 0;
        $readmemh("good.hex", img);
        #800000;                                     // POR ~0.65 ms
        spi_frame(2'b00, 0, 0);
        for (k2 = 0; k2 < 128; k2 = k2 + 1) spi_frame(2'b10, k2, img[k2]);
        spi_frame(2'b00, 0, 1);
        nstart = 0; nstop = 0;        // nstop=4: 3 STOP nyata + 1 tepi dari i2c_init() melepas SDA saat SCL high
        #6000000;
        $display("led=%h trap=%b nstart=%0d nstop=%0d ngot=%0d got=%h %h %h %h", led, led_trap, nstart, nstop, ngot, got[0], got[1], got[2], got[3]);
        if (led === 8'h5A && !led_trap && ngot == 7 && nstart == 4 && nstop == 4 && got[1] == 8'h00 && got[2] == 8'hAE && got[3] == 8'h5C) $display("PASS");
        else $display("FAIL");
        $finish;
    end
endmodule
