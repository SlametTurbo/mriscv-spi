// basys3_top_oled_tb.v -- uji oled_stress (build -DQUICK) di top tunggal.
// Dekoder I2C pasif di oled_scl/oled_sda: tiap transaksi data (ctl=0x40) dicatat
// (jumlah byte, jumlah 0xFF, jumlah 0x00). Dekoder UART menampilkan baris laporan.
// Cara pakai: lihat basys3_top_gpiobank_tb.v (bin -> good.hex), WORDS=jumlah word firmware.
`timescale 1ns/1ps
module tb;
    parameter WORDS = 720;
    reg clk100 = 0; always #5 clk100 = ~clk100;
    reg btnC = 0, spi_ceb = 1, spi_sclk = 0, spi_mosi = 0;
    wire [7:0] led; wire [6:0] seg; wire dp; wire [3:0] an;
    wire spi_miso, uart_txd, led_trap, oled_scl, oled_sda;
    pullup (oled_scl); pullup (oled_sda);
    basys3_top dut(.clk100(clk100), .btnC(btnC), .sw(8'h00), .led(led), .seg(seg), .dp(dp), .an(an),
        .spi_sclk(spi_sclk), .spi_ceb(spi_ceb), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .uart_txd(uart_txd), .uart_rxd(1'b1), .enc_clk(1'b1), .enc_dt(1'b1),
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

    // ---- dekoder I2C ----
    integer bitc = 0, nbyte = 0, nff = 0, nz = 0, ntx = 0, ndata_tx = 0, bad_addr = 0;
    reg [7:0] sh = 0, a0 = 0, ctl = 0;
    reg in_tx = 0;
    always @(negedge oled_sda) if (oled_scl === 1'b1) begin
        in_tx = 1; bitc = 0; nbyte = 0; nff = 0; nz = 0;
    end
    always @(posedge oled_scl) if (in_tx) begin
        if (bitc < 8) sh = {sh[6:0], oled_sda};
        bitc = bitc + 1;
        if (bitc == 9) begin
            if (nbyte == 0) begin a0 = sh; if (sh !== 8'h78) bad_addr = bad_addr + 1; end
            else if (nbyte == 1) ctl = sh;
            else begin if (sh == 8'hFF) nff = nff + 1; if (sh == 8'h00) nz = nz + 1; end
            nbyte = nbyte + 1; bitc = 0;
        end
    end
    always @(posedge oled_sda) if (oled_scl === 1'b1 && in_tx) begin
        in_tx = 0; ntx = ntx + 1;
        if (ctl == 8'h40 && nbyte > 2) begin
            ndata_tx = ndata_tx + 1;
            $display("[%0t ms] I2C frame#%0d data=%0d FF=%0d 00=%0d", $time/1000000, ndata_tx, nbyte-2, nff, nz);
        end
    end

    // ---- dekoder UART ----
    reg [7:0] rb; integer i, line_done = 0;
    initial forever begin
        @(negedge uart_txd); #(8680/2 + 8680);
        for (i = 0; i < 8; i = i + 1) begin rb[i] = uart_txd; #8680; end
        $write("%c", rb);
        if (rb == 8'h0A) line_done = line_done + 1;
    end

    reg [31:0] img [0:2047];
    initial begin
        for (i = 0; i < 2048; i = i + 1) img[i] = 0;
        $readmemh("good.hex", img);
        #800000;
        spi_frame(2'b00, 0, 0);
        for (i = 0; i < WORDS; i = i + 1) spi_frame(2'b10, i, img[i]);
        spi_frame(2'b00, 0, 1);
        i = 0;
        while (line_done < 2 && i < 40000) begin #100000; i = i + 1; end   // maks 4 s sim
        $display("\nI2C transaksi=%0d frame_data=%0d alamat_salah=%0d trap=%b ronde_terlapor=%0d",
                 ntx, ndata_tx, bad_addr, led_trap, line_done);
        $finish;
    end
endmodule
