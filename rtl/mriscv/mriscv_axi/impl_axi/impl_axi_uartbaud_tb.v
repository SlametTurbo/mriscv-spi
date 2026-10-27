// impl_axi_uartbaud_tb.v -- uji controller UART (uart.v) di SoC penuh: ganti
// baud lewat register BAUDDIV dari firmware, TX + RX di baud baru.
// Cara pakai: make build FW=uart_baud_test -> ubah .bin jadi good.hex (lihat
// impl_axi_busrst_tb.v langkah 3), lalu iverilog -g2012 -s tb ... + SP32B1024.v
// + semua .v non-tb, vvp.
// Dekoder TXD di tb ini memakai lebar bit SENDIRI (8680 ns / 4340 ns), bukan
// membaca register DUT, jadi kalau baud tidak benar-benar berubah teksnya rusak.
`timescale 1ns/1ps
module tb;
    reg CLK = 0; always #10 CLK = ~CLK;
    reg RST = 0, CEB = 1, SCLK = 0, MOSI = 0, RXD = 1;
    wire trap, txd, dout;
    wire [11:0] dac; wire [7:0] rx, tx, dnw, dse; wire sc, ss, sd;
    impl_axi dut(.CLK(CLK), .RST(RST), .trap(trap),
        .spi_axi_master_CEB(CEB), .spi_axi_master_SCLK(SCLK),
        .spi_axi_master_DATA(MOSI), .spi_axi_master_DOUT(dout),
        .DAC_interface_AXI_DATA(dac), .ADC_interface_AXI_BUSY(1'b0),
        .ADC_interface_AXI_DATA(10'd0), .completogpio_pindata(8'h00),
        .completogpio_Rx(rx), .completogpio_Tx(tx), .completogpio_datanw(dnw),
        .completogpio_DSE(dse), .spi_axi_slave_CEB(sc), .spi_axi_slave_SCLK(ss),
        .spi_axi_slave_DATA(sd), .uart_tx_TXD(txd), .uart_rx_RXD(RXD),
        .completogpio2_pindata(8'h00), .completogpio2_datanw(),
        .i2c_SCL_I(1'b1), .i2c_SDA_I(1'b1), .i2c_SCL_O(), .i2c_SDA_O());

    task spi_frame(input [1:0] instr, input [31:0] addr, input [31:0] data);
        reg [65:0] f; integer k;
        begin
            f = {instr, addr, data};
            CEB = 0; repeat (8) @(posedge CLK);
            for (k = 65; k >= 0; k = k - 1) begin
                MOSI = f[k]; repeat (4) @(posedge CLK);
                SCLK = 1;    repeat (4) @(posedge CLK);
                SCLK = 0;
            end
            repeat (4) @(posedge CLK); CEB = 1; repeat (16) @(posedge CLK);
        end
    endtask

    localparam B115 = 8680, B230 = 4340;     // ns per bit (DIV 434 / 217 @ 50 MHz)

    task host_send(input [7:0] b, input integer bt);
        integer j;
        begin
            RXD = 0; #(bt);
            for (j = 0; j < 8; j = j + 1) begin RXD = b[j]; #(bt); end
            RXD = 1; #(bt*2);
        end
    endtask

    // dekoder TXD: karakter 0-5 @115200, 6-15 @230400, 16+ @115200
    localparam [8*22-1:0] EXP = "A115\015\nB230\015\nwxyzC115\015\n";   // \015 = CR
    reg [7:0] got [0:63];
    reg [7:0] rxb; integer n = 0, bt, i, errors = 0;
    initial forever begin
        bt = (n >= 6 && n < 16) ? B230 : B115;
        @(negedge txd); #(bt/2);
        if (txd !== 1'b0) begin errors = errors + 1; $display("\nFAIL start bit karakter %0d", n); end
        #(bt);
        for (i = 0; i < 8; i = i + 1) begin rxb[i] = txd; #(bt); end
        if (txd !== 1'b1) begin errors = errors + 1; $display("\nFAIL stop bit karakter %0d", n); end
        $write("%c", rxb); got[n] = rxb; n = n + 1;
    end

    reg [31:0] img [0:2047];
    integer k;
    initial begin
        repeat (20) @(posedge CLK); RST = 1; repeat (20) @(posedge CLK);
        for (k = 0; k < 2048; k = k + 1) img[k] = 0;
        $readmemh("good.hex", img);
        spi_frame(2'b00, 0, 0);
        for (k = 0; k < 400; k = k + 1) spi_frame(2'b10, k, img[k]);
        spi_frame(2'b00, 0, 1);

        wait (n == 12);                          // "B230\r\n" selesai
        host_send("w", B230); host_send("x", B230);
        host_send("y", B230); host_send("z", B230);
        #(B115*10*12);
        $display("");

        if (n != 22) begin errors = errors + 1; $display("FAIL jumlah karakter %0d, harap 22", n); end
        for (k = 0; k < 22 && k < n; k = k + 1)
            if (got[k] !== EXP[8*(21-k) +: 8]) begin
                errors = errors + 1;
                $display("FAIL karakter %0d = %h, harap %h", k, got[k], EXP[8*(21-k) +: 8]);
            end
        if (dnw !== 8'h5A) begin errors = errors + 1; $display("FAIL LED = %h (firmware err)", dnw); end
        if (trap)          begin errors = errors + 1; $display("FAIL CPU trap"); end
        $display("trap=%0d LED=%h karakter=%0d", trap, dnw, n);
        if (errors == 0) $display("HASIL: PASS");
        else             $display("HASIL: FAIL (%0d kesalahan)", errors);
        $finish;
    end

    initial begin #20_000_000; $display("FAIL timeout (n=%0d)", n); $finish; end
endmodule
