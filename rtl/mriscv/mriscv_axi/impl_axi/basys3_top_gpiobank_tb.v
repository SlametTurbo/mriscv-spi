// basys3_top_gpiobank_tb.v -- uji 2 bank GPIO di top tunggal (firmware gpio_bank_test).
// Cara pakai: make build FW=gpio_bank_test -> .bin jadi good.hex (lihat impl_axi_busrst_tb.v),
// iverilog -g2012 -s tb basys3_top_gpiobank_tb.v + semua .v non-tb (sama dgn Makefile), vvp.
// Cek: led == sw (bank 1), oled_scl == enc_dt, oled_sda == enc_clk (bank 2, open-drain:
// pin 'z' = high lewat pull-up), tanpa trap.
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

    integer fails = 0, i;
    reg [31:0] img [0:2047];
    task check(input [7:0] s, input c, input d);
        begin
            sw = s; enc_clk = c; enc_dt = d;
            #400000;                                 // sinkronizer + beberapa putaran loop firmware (~20 transaksi bus/putaran)
            if (led !== s || oled_scl !== d || oled_sda !== c) begin
                fails = fails + 1;
                $display("FAIL sw=%h clk=%b dt=%b -> led=%h scl=%b sda=%b", s, c, d, led, oled_scl, oled_sda);
            end else $display("ok   sw=%h clk=%b dt=%b -> led=%h scl=%b sda=%b", s, c, d, led, oled_scl, oled_sda);
        end
    endtask

    initial begin
        for (i = 0; i < 2048; i = i + 1) img[i] = 0;
        $readmemh("good.hex", img);
        #800000;                                     // POR ~0.65 ms
        spi_frame(2'b00, 0, 0);
        for (i = 0; i < 64; i = i + 1) spi_frame(2'b10, i, img[i]);
        spi_frame(2'b00, 0, 1);
        #50000;
        check(8'h00, 1, 1); check(8'hA5, 0, 1); check(8'h5A, 1, 0);
        check(8'hFF, 0, 0); check(8'h81, 1, 1);
        $display("trap=%b fails=%0d  %s", led_trap, fails, (fails == 0 && !led_trap) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
