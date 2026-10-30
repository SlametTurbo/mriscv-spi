// impl_axi_addrmap_tb.v -- uji peta alamat AXI impl_axi (2026-10-09).
//
// Tujuan: menangkap kelas bug "override parameter interconnect hilang/salah"
// (CLAUDE.md "JANGAN DIRUSAK" #6 dan UART poin 1) yang tetap lolos elaborate:
// kalau addr_mask/addr_use/slaves tidak sampai ke axi4_interconnect, atau
// rentang dua slave tumpang tindih, atau slave baru disambung ke indeks yang
// salah, testbench ini FAIL dan menyebut alamat + slave yang kena.
//
// Tabel HARAPAN di bawah sengaja ditulis ulang manual (BUKAN dibaca dari
// localparam impl_axi.v) -- kalau impl_axi.v berubah tanpa tabel ini ikut
// diubah, itu juga harus ketahuan. Menambah slave baru = tambah baris probe.
//
// Tiga fase, tanpa file firmware/.hex:
//   [W] TULIS lewat spi_axi_master (persis frame cheetah_mriscv.py), CPU ditahan.
//       Cek: s_axi_awvalid one-hot ke slave yang benar + transaksi selesai,
//       ditambah efek samping yang mudah dicek (isi SRAM, pin GPIO 1/2,
//       byte UART TX mulai, register BAUDDIV UART, register DIV I2C).
//   [R] BACA lewat CPU: program RV32I kecil (lui+lw per alamat, di-encode di
//       tb ini) di-upload lewat SPI lalu dijalankan. Cek s_axi_arvalid
//       one-hot per alamat + trap=0.
//   [U] Alamat di LUAR peta: tidak boleh ada slave yang terpilih. Catatan:
//       interconnect tidak punya DECERR, jadi tulis ke alamat kosong
//       menggantung bus sampai RST -- tb pulsa RST setelah tiap probe.
//
// Cara pakai (dari root repo):
//   iverilog -g2012 -s tb -o build/addrmap.vvp \
//       rtl/mriscv/mriscv_axi/impl_axi/impl_axi_addrmap_tb.v rtl/SP32B1024.v \
//       $(find rtl/mriscv/mriscv_axi rtl/mriscv/mriscvcore -name '*.v' ! -name '*_tb.v' \
//         ! -path '*/tests/*' ! -path '*/firmware/*')
//   vvp build/addrmap.vvp
// Hasil akhir: baris "HASIL: PASS" / "HASIL: FAIL (n kesalahan)".
`timescale 1ns/1ps
module tb;
    reg CLK = 0; always #10 CLK = ~CLK;      // 50 MHz
    reg RST = 0;
    reg CEB = 1, SCLK = 0, MOSI = 0;
    wire trap, txd, dout;
    wire [11:0] dac; wire [7:0] rx, tx, dnw, dse, dnw2; wire sc, ss, sd;
    wire scl_o, sda_o;

    impl_axi dut(.CLK(CLK), .RST(RST), .trap(trap),
        .spi_axi_master_CEB(CEB), .spi_axi_master_SCLK(SCLK),
        .spi_axi_master_DATA(MOSI), .spi_axi_master_DOUT(dout),
        .DAC_interface_AXI_DATA(dac), .ADC_interface_AXI_BUSY(1'b0),
        .ADC_interface_AXI_DATA(10'd0), .completogpio_pindata(8'h00),
        .completogpio_Rx(rx), .completogpio_Tx(tx), .completogpio_datanw(dnw),
        .completogpio_DSE(dse), .spi_axi_slave_CEB(sc), .spi_axi_slave_SCLK(ss),
        .spi_axi_slave_DATA(sd), .uart_tx_TXD(txd), .uart_rx_RXD(1'b1),
        .completogpio2_pindata(8'h00), .completogpio2_datanw(dnw2),
        .i2c_SCL_I(1'b1), .i2c_SDA_I(1'b1), .i2c_SCL_O(scl_o), .i2c_SDA_O(sda_o));

    localparam NSLV = 8;                     // harus sama dgn localparam slaves di impl_axi.v
    localparam NONE = -1;

    // ---------------- tabel harapan (alamat WORD, seperti di bus) ----------------
    localparam NP = 16;
    reg [31:0] p_addr [0:NP-1];
    integer    p_slv  [0:NP-1];
    initial begin
        // Peta 2026-10-30: slave n di word n<<14, mask jendela penuh 0x3FFF
        // (SRAM 0x1FFF). Tiap slave diprobe di awal & akhir jendela; probe akhir
        // jendela juga menguji alias (slave cuma memakai bit alamat rendah).
        // SRAM 32 KB: 0x0000-0x1FFF (dua titik, bukan 0 supaya tidak menimpa program)
        p_addr[ 0] = 32'h0000_0100; p_slv[ 0] = 0;
        p_addr[ 1] = 32'h0000_1FFF; p_slv[ 1] = 0;
        p_addr[ 2] = 32'h0000_4000; p_slv[ 2] = 1;   // DAC  0x4000-0x7FFF
        p_addr[ 3] = 32'h0000_7FFF; p_slv[ 3] = 1;
        p_addr[ 4] = 32'h0000_8000; p_slv[ 4] = 2;   // ADC  0x8000-0xBFFF
        p_addr[ 5] = 32'h0000_BFFF; p_slv[ 5] = 2;
        p_addr[ 6] = 32'h0000_C000; p_slv[ 6] = 3;   // GPIO 0xC000-0xFFFF (pin0)
        p_addr[ 7] = 32'h0000_FFFF; p_slv[ 7] = 3;   // (alias pin7)
        p_addr[ 8] = 32'h0001_7FFF; p_slv[ 8] = 5;   // UART 0x14000-0x17FFF (alias BAUDDIV)
        p_addr[ 9] = 32'h0001_4000; p_slv[ 9] = 5;   // (TXDATA; tulis setelah BAUDDIV,
                                                     //  kalau tx_busy BAUDDIV ditolak)
        p_addr[10] = 32'h0001_8000; p_slv[10] = 6;   // GPIO bank 2 0x18000-0x1BFFF (pin0)
        p_addr[11] = 32'h0001_BFFF; p_slv[11] = 6;   // (alias pin7)
        p_addr[12] = 32'h0001_C000; p_slv[12] = 7;   // I2C 0x1C000-0x1FFFF (DATA)
        p_addr[13] = 32'h0001_FFFF; p_slv[13] = 7;   // (alias DIV)
        p_addr[14] = 32'h0001_0000; p_slv[14] = 4;   // SPI slave 0x10000-0x13FFF
        p_addr[15] = 32'h0001_3FFF; p_slv[15] = 4;   // (paling akhir di [R])
    end
    localparam NU = 6;                       // probe [U] tambahan
    reg [31:0] u_addr [0:NU-1];
    initial begin
        u_addr[0] = 32'h0000_2000; u_addr[1] = 32'h0000_3FFF;   // celah SRAM 32-64 KB
        u_addr[2] = 32'h0002_0000; u_addr[3] = 32'h0003_FFFF;   // slot 8-15 kosong
        u_addr[4] = 32'h0400_0000;                              // alamat SPI slave lama
        u_addr[5] = 32'h8000_C000;                              // bit atas wajib dibandingkan
    end

    integer errors = 0;

    // ---------------- SPI master host (sama dgn impl_axi_busrst_tb) ----------------
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
            repeat (4) @(posedge CLK); CEB = 1; repeat (4) @(posedge CLK);
        end
    endtask

    task reset_all;
        begin
            RST = 0; repeat (20) @(posedge CLK); RST = 1; repeat (20) @(posedge CLK);
        end
    endtask

    // ---------------- monitor decode tulis ----------------
    // dikosongkan lewat aw_clr (diubah di negedge, supaya tidak balapan dgn posedge)
    reg [NSLV-1:0] aw_seen = 0;
    reg            aw_clr  = 0;
    always @(posedge CLK)
        if (aw_clr) aw_seen <= 0;
        else        aw_seen <= aw_seen | dut.s_axi_awvalid;

    function integer onehot_idx(input [NSLV-1:0] v);   // -1 kosong, -2 lebih dari satu
        integer i, n;
        begin
            onehot_idx = NONE; n = 0;
            for (i = 0; i < NSLV; i = i + 1) if (v[i]) begin onehot_idx = i; n = n + 1; end
            if (n > 1) onehot_idx = -2;
        end
    endfunction

    // tulis satu kata lewat SPI, tunggu master balik idle (atau timeout)
    task probe_write(input [31:0] a, input [31:0] d, input integer exp);
        integer t, got; reg done;
        begin
            @(negedge CLK) aw_clr = 1; @(negedge CLK) aw_clr = 0;
            spi_frame(2'b10, a, d);
            done = 0;
            for (t = 0; t < 20000 && !done; t = t + 1) begin
                @(posedge CLK);
                if (dut.inst_spi_axi_master.st == 0 && !dut.inst_spi_axi_master.do_write
                    && aw_seen != 0) done = 1;
            end
            if (exp == NONE) repeat (200) @(posedge CLK);   // beri waktu decode salah muncul
            got = onehot_idx(aw_seen);
            if (got != exp || (exp != NONE && !done)) begin
                errors = errors + 1;
                $display("  FAIL [W] word 0x%08h: harap slave %0d, dapat %0s%0d (awvalid=%b)%0s",
                         a, exp, got == -2 ? "BANYAK " : "", got, aw_seen,
                         (exp != NONE && !done) ? " -- transaksi tidak selesai" : "");
            end else
                $display("  ok   [W] word 0x%08h -> slave %0d", a, got);
        end
    endtask

    // ---------------- monitor decode baca (master 0 = CPU) ----------------
    // Catat slave yang terpilih untuk tiap araddr data (fetch < 0x100 diabaikan),
    // dan apakah handshake R (rvalid & rready) benar-benar terjadi.
    reg [NSLV-1:0] ar_hit [0:NP-1];
    reg            ar_done [0:NP-1];
    integer j;
    initial for (j = 0; j < NP; j = j + 1) begin ar_hit[j] = 0; ar_done[j] = 0; end
    always @(posedge CLK)
        for (j = 0; j < NP; j = j + 1)
            if (dut.inst_axi4_interconnect.araddr == p_addr[j] && p_addr[j] >= 32'h100) begin
                ar_hit[j] = ar_hit[j] | dut.s_axi_arvalid;
                if ((dut.s_axi_rvalid & dut.s_axi_rready) != 0) ar_done[j] = 1;
            end

    // ---------------- encoder RV32I mini ----------------
    function [31:0] LUI(input [4:0] rd, input [19:0] imm);
        LUI = {imm, rd, 7'b0110111};
    endfunction
    function [31:0] LW(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        LW = {imm, rs1, 3'b010, rd, 7'b0000011};
    endfunction

    reg [31:0] prog [0:63];
    integer np, i, k, exp_cnt;
    reg [31:0] ba, hi;
    reg uart_started = 0;
    always @(posedge CLK) if (dut.inst_uart.start_pulse) uart_started <= 1;

    initial begin
        reset_all;

        // ================= [W] tulis lewat SPI, CPU ditahan =================
        $display("[W] decode TULIS lewat spi_axi_master");
        spi_frame(2'b00, 0, 0);                                  // tahan CPU
        repeat (20) @(posedge CLK);
        for (i = 0; i < NP; i = i + 1) begin
            case (i)
                0, 1:  probe_write(p_addr[i], 32'hA5A5_0000 | i, p_slv[i]);  // pola SRAM
                6, 7, 10, 11:
                       probe_write(p_addr[i], 32'h3, p_slv[i]);     // GPIO 1/2 pin0 & pin7 = 1
                8:     probe_write(p_addr[i], 32'd217, p_slv[i]);   // UART BAUDDIV = 217 (230400)
                9:     probe_write(p_addr[i], 32'h55, p_slv[i]);    // UART TX kirim 'U'
                13:    probe_write(p_addr[i], 32'd50, p_slv[i]);    // I2C DIV = 50
                default: probe_write(p_addr[i], 32'h0, p_slv[i]);
            endcase
        end
        // efek samping: memastikan data benar-benar sampai ke modul yang dimaksud
        if (dut.SP32B1024_INT.mem[13'h0100] !== 32'hA5A5_0000 ||
            dut.SP32B1024_INT.mem[13'h1FFF] !== 32'hA5A5_0001) begin
            errors = errors + 1;
            $display("  FAIL [W] isi SRAM: mem[0x100]=%h mem[0x1FFF]=%h",
                     dut.SP32B1024_INT.mem[13'h0100], dut.SP32B1024_INT.mem[13'h1FFF]);
        end
        if (dnw  !== 8'h81) begin errors = errors + 1; $display("  FAIL [W] GPIO bank 1 = %b, harap 10000001", dnw); end
        if (dnw2 !== 8'h81) begin errors = errors + 1; $display("  FAIL [W] GPIO bank 2 = %b, harap 10000001", dnw2); end
        if (!uart_started)    begin errors = errors + 1; $display("  FAIL [W] UART TX tidak mulai kirim"); end
        if (dut.inst_uart.div !== 16'd217) begin
            errors = errors + 1; $display("  FAIL [W] BAUDDIV UART = %0d, harap 217", dut.inst_uart.div);
        end
        if (dut.inst_i2c_master.div !== 16'd50) begin
            errors = errors + 1; $display("  FAIL [W] DIV I2C = %0d, harap 50", dut.inst_i2c_master.div);
        end

        // ================= [R] baca lewat CPU =================
        $display("[R] decode BACA lewat CPU (lui+lw per alamat)");
        np = 0;
        for (k = 0; k < NP; k = k + 1) begin
            ba = p_addr[k] << 2;                                  // alamat byte CPU
            hi = (ba + 32'h800) >> 12;
            prog[np] = LUI(5'd5, hi[19:0]);               np = np + 1;
            prog[np] = LW (5'd6, 5'd5, ba[11:0]);         np = np + 1;
        end
        prog[np] = 32'h0000_006F; np = np + 1;                    // j .
        spi_frame(2'b00, 0, 0);
        for (i = 0; i < np; i = i + 1) spi_frame(2'b10, i, prog[i]);
        spi_frame(2'b00, 0, 1);                                   // lepas CPU
        repeat (20000) @(posedge CLK);
        for (i = 0; i < NP; i = i + 1) begin
            k = onehot_idx(ar_hit[i]);
            if (k != p_slv[i]) begin
                errors = errors + 1;
                $display("  FAIL [R] word 0x%08h: harap slave %0d, dapat %0s%0d (arvalid=%b)",
                         p_addr[i], p_slv[i], k == -2 ? "BANYAK " : "", k, ar_hit[i]);
            end else if (!ar_done[i]) begin
                errors = errors + 1;
                $display("  FAIL [R] word 0x%08h -> slave %0d, tapi data baca tidak pernah kembali",
                         p_addr[i], k);
            end else
                $display("  ok   [R] word 0x%08h -> slave %0d", p_addr[i], k);
        end
        if (trap) begin errors = errors + 1; $display("  FAIL [R] CPU trap"); end

        // ================= [U] alamat di luar peta =================
        $display("[U] alamat di LUAR peta tidak boleh memilih slave");
        for (i = 0; i < NU; i = i + 1) begin
            reset_all;
            spi_frame(2'b00, 0, 0);
            repeat (20) @(posedge CLK);
            probe_write(u_addr[i], 32'h0, NONE);
        end

        if (errors == 0) $display("HASIL: PASS");
        else             $display("HASIL: FAIL (%0d kesalahan)", errors);
        $finish;
    end
endmodule
