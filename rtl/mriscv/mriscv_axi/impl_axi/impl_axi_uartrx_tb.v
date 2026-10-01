// impl_axi_uartrx_tb.v -- uji UART RX end-to-end di SoC penuh (firmware uart_echo).
// Cara pakai: make build FW=uart_echo -> ubah .bin jadi good.hex (lihat
// impl_axi_busrst_tb.v langkah 3), lalu iverilog -g2012 -s tb ... + SP32B1024.v
// + semua .v non-tb, vvp. Host mengirim "Hi?" + 0x55 lewat RXD @115200;
// TXD harus mengembalikan banner + echo + statistik.
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
        .completogpio2_pindata(8'h00), .completogpio2_datanw());

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

    reg [31:0] img [0:2047];
    integer i;
    task host_send(input [7:0] b);   // 115200 baud = 8680 ns/bit
        integer j;
        begin
            RXD = 0; #8680;
            for (j = 0; j < 8; j = j + 1) begin RXD = b[j]; #8680; end
            RXD = 1; #(8680*2);
        end
    endtask

    // dekoder UART TX -> string
    reg [7:0] rxb; integer n = 0;
    initial forever begin
        @(negedge txd); #(8680/2 + 8680);
        for (i = 0; i < 8; i = i + 1) begin rxb[i] = txd; #8680; end
        $write("%c", rxb); n = n + 1;
    end

    initial begin
        repeat (20) @(posedge CLK); RST = 1; repeat (20) @(posedge CLK);
        for (i = 0; i < 2048; i = i + 1) img[i] = 0;
        $readmemh("good.hex", img);
        spi_frame(2'b00, 0, 0);
        for (i = 0; i < 400; i = i + 1) spi_frame(2'b10, i, img[i]);
        spi_frame(2'b00, 0, 1);
        #(8680*20*10);                  // banner selesai
        $write("\n[kirim] Hi?U -> [balasan] ");
        host_send("H"); host_send("i"); host_send("?"); host_send(8'h55);
        #(8680*200);
        $display("\ntrap=%0d karakter=%0d", trap, n);
        $finish;
    end
endmodule
