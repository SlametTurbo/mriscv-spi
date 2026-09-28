`timescale 1ns / 1ps
// ============================================================================
// uart_tx.v -- UART TX-only, slave AXI4-lite. 8N1, LSB-first.
//
// Tulis WDATA[7:0] ke alamat manapun dalam range slave ini -> kirim 1 byte.
// Transaksi AXI SELALU cepat (non-blocking, beberapa siklus saja, sama
// seperti GPIO/DAC/ADC) -- TIDAK PERNAH menahan bus lama. Kalau transmitter
// masih sibuk, byte yang ditulis diam-diam DIABAIKAN. Firmware WAJIB polling
// RDATA[0] (busy) dulu sebelum tulis byte berikutnya -- lihat uart_putc() di
// mriscv.h. Lihat komentar di FSM tulis di bawah untuk alasan desain ini.
//
// Baca alamat manapun -> RDATA[0] = busy (1 = sedang transmit).
//
// Baud rate FIXED, dihitung dari CLK_HZ (default 50 MHz, sesuai clock core
// proyek ini) / BAUD (default 9600). Kalau clock core proyek diubah, parameter
// CLK_HZ di instansiasi WAJIB disesuaikan juga, kalau tidak baud rate salah.
// ============================================================================
module uart_tx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 9600
)(
    input             CLK, RST,
    input             AWVALID, input WVALID, input BREADY,
    input      [31:0] AWADDR,
    input      [31:0] WDATA,
    input      [3:0]  WSTRB,
    output reg        AWREADY, output reg WREADY, output reg BVALID,

    input             ARVALID, input RREADY,
    input      [31:0] ARADDR,
    output reg        ARREADY, output reg RVALID,
    output reg [31:0] RDATA,

    output            TXD
);
    localparam integer DIV  = CLK_HZ / BAUD;
    localparam integer DIVW = $clog2(DIV);

    // ---- transmitter engine ----
    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;
    reg [1:0]      tstate  = S_IDLE;
    reg [DIVW-1:0] baudcnt = 0;
    reg [2:0]      bitidx  = 0;
    reg [7:0]      shreg   = 0;
    reg            txd_r   = 1'b1;
    // start_pulse ikut dihitung "busy" -- tanpa ini ada window 1 siklus
    // antara start_pulse di-assert dan tstate BENAR-BENAR pindah dari
    // S_IDLE, di mana write kedua yang datang pas di window itu masih lolos
    // dianggap "!busy" dan menimpa wdata_byte sebelum byte pertama sempat
    // mulai transmit (race condition nyata, ketahuan dari testbench).
    wire           busy    = (tstate != S_IDLE) || start_pulse;
    assign TXD = txd_r;

    reg       start_pulse = 1'b0;
    reg [7:0] wdata_byte  = 0;

    always @(posedge CLK) begin
        if (!RST) begin
            tstate <= S_IDLE; baudcnt <= 0; bitidx <= 0; txd_r <= 1'b1; shreg <= 0;
        end else begin
            case (tstate)
                S_IDLE: begin
                    txd_r <= 1'b1;
                    if (start_pulse) begin
                        shreg   <= wdata_byte;
                        baudcnt <= 0;
                        tstate  <= S_START;
                    end
                end
                S_START: begin
                    txd_r <= 1'b0;               // start bit
                    if (baudcnt == DIV-1) begin
                        baudcnt <= 0; bitidx <= 0; tstate <= S_DATA;
                    end else baudcnt <= baudcnt + 1'b1;
                end
                S_DATA: begin
                    txd_r <= shreg[0];            // LSB-first
                    if (baudcnt == DIV-1) begin
                        baudcnt <= 0;
                        shreg   <= {1'b0, shreg[7:1]};
                        if (bitidx == 3'd7) tstate <= S_STOP;
                        else bitidx <= bitidx + 1'b1;
                    end else baudcnt <= baudcnt + 1'b1;
                end
                S_STOP: begin
                    txd_r <= 1'b1;                // stop bit
                    if (baudcnt == DIV-1) begin
                        baudcnt <= 0; tstate <= S_IDLE;
                    end else baudcnt <= baudcnt + 1'b1;
                end
                default: tstate <= S_IDLE;
            endcase
        end
    end

    // ---- AXI4-lite write FSM: SELALU terima cepat (non-blocking), sama
    // seperti GPIO/DAC/ADC -- TIDAK PERNAH menahan bus AXI lama.
    //
    // (Riwayat: dua desain sebelumnya SAMA-SAMA bikin CPU macet permanen di
    // hardware asli meski lolos simulasi & lolos elaborate check:
    //   1) AW_IDLE terima duluan, baru nunggu !busy di state terpisah --
    //      BUG data (byte baru menimpa byte lama), TAPI ternyata bukan itu
    //      yang bikin hang.
    //   2) AW_IDLE nunggu !busy DULU baru accept (gating di titik accept) --
    //      benar secara protokol AXI, lolos testbench, TAPI CPU tetap macet
    //      permanen di hardware nyata SPESIFIK saat program menahan
    //      AWvalid/Wvalid selama ribuan-puluhan ribu siklus berturut-turut
    //      (durasi 1 baud period @ 9600bps = ~52080 siklus @ 50MHz) sambil
    //      nunggu !busy -- program lain (GPIO dibaca-tulis berulang, dst)
    //      yang TIDAK PERNAH menahan bus selama itu semua terbukti aman.
    //      Kemungkinan root cause: timing marginal/metastabilitas di suatu
    //      sinyal kontrol (mis. jalur tri-state axi4_interconnect) yang
    //      hanya kelihatan kalau dipertahankan pada state yang sama utk
    //      puluhan ribu siklus terus-menerus -- BUKAN sesuatu yang keluar
    //      dari analisis static timing (Fmax) biasa.
    // Solusi: JANGAN PERNAH menahan channel AW/W lama-lama dari hardware.
    // Transaksi AXI SELALU selesai dalam beberapa siklus (persis kayak
    // GPIO). Byte baru diterima & di-drop diam-diam kalau transmitter masih
    // busy -- firmware WAJIB polling uart_busy() dulu sebelum tulis byte
    // berikutnya (lihat uart_putc() di mriscv.h, sudah diupdate).
    localparam AW_IDLE = 1'd0, AW_RESP = 1'd1;
    reg awstate = AW_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            awstate <= AW_IDLE; AWREADY <= 0; WREADY <= 0; BVALID <= 0;
            start_pulse <= 0; wdata_byte <= 0;
        end else begin
            start_pulse <= 1'b0;
            AWREADY <= 0;
            WREADY  <= 0;
            case (awstate)
                AW_IDLE: begin
                    BVALID <= 0;
                    if (AWVALID && WVALID) begin
                        AWREADY     <= 1;
                        WREADY      <= 1;
                        if (!busy) begin
                            wdata_byte  <= WDATA[7:0];
                            start_pulse <= 1'b1;
                        end
                        // kalau busy: write diterima (AXI selesai cepat)
                        // tapi diabaikan diam-diam -- firmware seharusnya
                        // tidak pernah menulis saat busy (sudah polling).
                        awstate <= AW_RESP;
                    end
                end
                AW_RESP: begin
                    BVALID <= 1;
                    // gating pakai BVALID lama (teregister): kalau BREADY sudah
                    // tinggi SEBELUM BVALID sempat teregister 1, jangan langsung
                    // clear di siklus yang sama -- BVALID harus kelihatan 1 dulu
                    // minimal 1 siklus penuh dari luar sebelum transaksi selesai.
                    if (BVALID && BREADY) begin BVALID <= 0; awstate <= AW_IDLE; end
                end
                default: awstate <= AW_IDLE;
            endcase
        end
    end

    // ---- AXI4-lite read FSM: RDATA[0] = busy ----
    localparam AR_IDLE = 1'b0, AR_RESP = 1'b1;
    reg ar_state = AR_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            ar_state <= AR_IDLE; ARREADY <= 0; RVALID <= 0; RDATA <= 0;
        end else case (ar_state)
            AR_IDLE: begin
                RVALID <= 0;
                if (ARVALID) begin
                    ARREADY  <= 1;
                    RDATA    <= {31'b0, busy};
                    ar_state <= AR_RESP;
                end
            end
            AR_RESP: begin
                ARREADY <= 0; RVALID <= 1;
                // gating sama seperti AW_RESP -- lihat komentar di sana.
                if (RVALID && RREADY) begin RVALID <= 0; ar_state <= AR_IDLE; end
            end
            default: ar_state <= AR_IDLE;
        endcase
    end
endmodule
