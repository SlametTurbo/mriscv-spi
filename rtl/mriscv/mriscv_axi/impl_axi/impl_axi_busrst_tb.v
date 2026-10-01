// impl_axi_busrst_tb.v -- testbench fungsional BUS_RST (task 2b, 2026-09-28).
//
// Cara pakai (dari root repo):
//   1) Buat firmware yang trap: kompilasi uart_probe6_4c.c dengan linker .bss
//      LAMA (tanpa ALIGN(4) di dalam section), mis.
//        git show d22f868~1:link_c.ld > /tmp/old.ld
//        riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
//            -ffreestanding -Os -T /tmp/old.ld crt0.S uart_probe6_4c.c -o bad.elf
//        riscv64-unknown-elf-objcopy -O binary bad.elf bad.bin
//   2) make build FW=uart_probe7   (-> uart_probe7.bin)
//   3) Ubah kedua .bin jadi hex satu kata per baris (little-endian) -> bad.hex, good.hex
//      python3 -c "import struct,sys;d=open(sys.argv[1],'rb').read();d+=b'\0'*(-len(d)%4);print('\n'.join('%08x'%struct.unpack('<I',d[i:i+4])[0] for i in range(0,len(d),4)))" bad.bin > bad.hex
//   4) iverilog -g2012 -s tb -o tb.vvp mriscv/mriscv_axi/impl_axi/impl_axi_busrst_tb.v SP32B1024.v <semua .v non-tb> && vvp tb.vvp
//      Tambah -DNO_BUSRST untuk mematikan fix (harus FAIL: upload kedua gagal).
// Hasil 2026-09-28: dengan fix PASS ("Hello UART @", SRAM benar), -DNO_BUSRST FAIL.
`timescale 1ns/1ps
// Testbench reset bus (task 2b): upload firmware yang trap di tengah
// transaksi AXI, lalu upload firmware kedua (uart_probe7) lewat SPI persis
// seperti cheetah_mriscv.py, dan cek apakah firmware kedua benar-benar jalan
// (karakter keluar lewat uart_tx). Kompilasi dengan -DNO_BUSRST untuk
// mematikan fix dan memastikan testbench memang mereproduksi bug.
module tb;
    reg CLK = 0; always #10 CLK = ~CLK;      // 50 MHz
    reg RST = 0;
    reg CEB = 1, SCLK = 0, MOSI = 0;
    wire trap, txd, dout;
    wire [11:0] dac; wire [7:0] rx, tx, dnw, dse; wire sc, ss, sd;

    impl_axi dut(.CLK(CLK), .RST(RST), .trap(trap),
        .spi_axi_master_CEB(CEB), .spi_axi_master_SCLK(SCLK),
        .spi_axi_master_DATA(MOSI), .spi_axi_master_DOUT(dout),
        .DAC_interface_AXI_DATA(dac), .ADC_interface_AXI_BUSY(1'b0),
        .ADC_interface_AXI_DATA(10'd0), .completogpio_pindata(8'h00),
        .completogpio_Rx(rx), .completogpio_Tx(tx), .completogpio_datanw(dnw),
        .completogpio_DSE(dse), .spi_axi_slave_CEB(sc), .spi_axi_slave_SCLK(ss),
        .spi_axi_slave_DATA(sd), .uart_tx_TXD(txd), .uart_rx_RXD(1'b1),
        .completogpio2_pindata(8'h00), .completogpio2_datanw());

`ifdef NO_BUSRST
    initial force dut.busrst_n_r = 1'b1;     // fix dimatikan
`endif

    // SCLK = CLK/8 (jauh di bawah batas 1/4)
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

    reg [31:0] img [0:127];
    task upload(input integer nwords);
        integer i;
        begin
            spi_frame(2'b00, 0, 0);                     // tahan CPU
            for (i = 0; i < nwords; i = i + 1) spi_frame(2'b10, i, img[i]);
            spi_frame(2'b00, 0, 1);                     // lepas CPU
        end
    endtask

    // pantau byte yang benar-benar dikirim uart_tx
    integer nchar = 0;
    always @(posedge CLK)
        if (dut.inst_uart_tx.start_pulse) begin
            nchar = nchar + 1;
            if (nchar <= 12) $write("%c", dut.inst_uart_tx.wdata_byte);
        end

    integer i, ok;
    initial begin
        repeat (20) @(posedge CLK); RST = 1; repeat (20) @(posedge CLK);

        // 1) firmware .bss misaligned -> trap di crt0 (sw misaligned)
        for (i = 0; i < 128; i = i + 1) img[i] = 0;
        $readmemh("bad.hex", img);
        upload(128);                 // seluruh buffer (sisa = 0), tidak bergantung ukuran firmware
        repeat (3000) @(posedge CLK);
        $display("[1] setelah firmware buruk: trap=%0d  wtrans=%0d rtrans=%0d",
                 trap, dut.inst_axi4_interconnect.wtrans, dut.inst_axi4_interconnect.rtrans);

        // 2) upload firmware kedua (uart_probe7) persis seperti host
        for (i = 0; i < 128; i = i + 1) img[i] = 0;
        $readmemh("good.hex", img);
        upload(128);
        ok = 1;
        for (i = 0; i < 128; i = i + 1)
            if (dut.SP32B1024_INT.mem[i] !== img[i]) ok = 0;
        $display("[2] isi SRAM setelah upload kedua %s", ok ? "BENAR" : "SALAH (upload gagal)");
        $write("[3] output UART firmware kedua: \"");
        repeat (80000) @(posedge CLK);
        $display("\"  (%0d karakter, trap=%0d)", nchar, trap);
        $display("HASIL: %s", (ok && nchar >= 5 && !trap) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
