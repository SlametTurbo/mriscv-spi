`timescale 1ns / 1ps
// ============================================================================
// uart.v -- UART controller TX + RX dalam SATU slave AXI4-lite, 8N1, LSB-first,
// baud rate bisa diubah lewat register. Menggantikan uart_tx.v + uart_rx.v
// (dua slave terpisah) -- engine TX/RX di bawah sama dengan kedua modul itu,
// bedanya pembagi baud sekarang register, bukan localparam.
//
// REGISTER (dipilih lewat ADDR[1:0] = indeks word di dalam slave; byte base
// 0x10080 -- alamat +0/+4 SAMA dengan uart_tx/uart_rx lama, jadi firmware
// lama tetap jalan tanpa diubah):
//   0 TXDATA  tulis: kirim WDATA[7:0] (diabaikan diam-diam kalau tx_busy)
//             baca : STATUS (sama dengan reg 2, TIDAK pop) -- bit0 = tx_busy
//                    seperti uart_tx lama
//   1 RXDATA  baca : bit[7:0] byte, bit8 valid, bit9 overrun, bit10 ferr.
//                    Baca = POP (menghapus valid/overrun/ferr), sama dengan
//                    uart_rx lama. Tulis diterima & diabaikan.
//   2 STATUS  baca : bit0 tx_busy, bit1 rx_valid, bit2 rx_overrun,
//                    bit3 rx_ferr, bit4 rx_busy (sedang menerima frame).
//                    Tidak pop. Tulis diabaikan.
//   3 BAUDDIV tulis/baca: [15:0] = jumlah clock per bit (= CLK_HZ / baud).
//             Reset = CLK_HZ/BAUD (434 = 115200 @ 50 MHz). Tulis DIABAIKAN
//             kalau nilai < DIV_MIN, atau tx_busy, atau rx_busy (ganti baud
//             di tengah frame merusak frame itu). Firmware tulis lalu baca
//             balik untuk memastikan (lihat uart_set_div() di mriscv.h).
//
// Semua transaksi AXI non-blocking (selesai beberapa siklus) -- JANGAN ubah
// jadi menahan AW/W sampai !busy, lihat riwayat di uart_tx.v.
//
// Pembagi integer: error baud = |CLK_HZ/DIV - baud| / baud. Contoh @ 50 MHz:
// 9600 -> 5208 (0.006%), 115200 -> 434 (0.006%), 230400 -> 217 (0.006%),
// 460800 -> 109 (0.45%), 921600 -> 54 (0.47%). Toleransi UART ~2%.
// ============================================================================
module uart #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115200          // baud awal setelah reset
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

    output            TXD,
    input             RXD
);
    localparam [15:0] DIV_DEF = CLK_HZ / BAUD;
    localparam [15:0] DIV_MIN = 16'd16;     // 3.125 Mbaud @ 50 MHz

    // ---- register pembagi baud ----
    // div_m1/half_m1 disimpan teregister (bukan dihitung dari div di tiap
    // perbandingan) supaya tidak ada pengurang di jalur counter.
    reg [15:0] div     = DIV_DEF;
    reg [15:0] div_m1  = DIV_DEF - 1;       // akhir 1 periode bit
    reg [15:0] half_m1 = DIV_DEF/2 - 1;     // tengah start bit (RX)

    // ======================= transmitter =======================
    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;
    reg [1:0]  tstate  = S_IDLE;
    reg [15:0] tcnt    = 0;
    reg [2:0]  tbit    = 0;
    reg [7:0]  tsh     = 0;
    reg        txd_r   = 1'b1;
    reg        start_pulse = 1'b0;
    reg [7:0]  wdata_byte  = 0;
    // start_pulse ikut "busy" -- race 1 siklus, lihat komentar di uart_tx.v
    wire       tx_busy = (tstate != S_IDLE) || start_pulse;
    assign TXD = txd_r;

    always @(posedge CLK) begin
        if (!RST) begin
            tstate <= S_IDLE; tcnt <= 0; tbit <= 0; txd_r <= 1'b1; tsh <= 0;
        end else case (tstate)
            S_IDLE: begin
                txd_r <= 1'b1;
                if (start_pulse) begin
                    tsh <= wdata_byte; tcnt <= 0; tstate <= S_START;
                end
            end
            S_START: begin
                txd_r <= 1'b0;                      // start bit
                if (tcnt == div_m1) begin
                    tcnt <= 0; tbit <= 0; tstate <= S_DATA;
                end else tcnt <= tcnt + 1'b1;
            end
            S_DATA: begin
                txd_r <= tsh[0];                    // LSB-first
                if (tcnt == div_m1) begin
                    tcnt <= 0;
                    tsh  <= {1'b0, tsh[7:1]};
                    if (tbit == 3'd7) tstate <= S_STOP;
                    else tbit <= tbit + 1'b1;
                end else tcnt <= tcnt + 1'b1;
            end
            S_STOP: begin
                txd_r <= 1'b1;                      // stop bit
                if (tcnt == div_m1) begin
                    tcnt <= 0; tstate <= S_IDLE;
                end else tcnt <= tcnt + 1'b1;
            end
        endcase
    end

    // ======================= receiver =======================
    // sinkronizer 2-FF (RXD asinkron terhadap CLK)
    reg rxd_m = 1'b1, rxd_s = 1'b1;
    always @(posedge CLK) begin rxd_m <= RXD; rxd_s <= rxd_m; end

    localparam R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2, R_STOP = 2'd3;
    reg [1:0]  rstate = R_IDLE;
    reg [15:0] rcnt   = 0;
    reg [2:0]  rbit   = 0;
    reg [7:0]  rsh    = 0;
    reg        done    = 1'b0;              // pulsa 1 siklus: 1 byte selesai
    reg        done_fe = 1'b0;              // stop bit salah (valid saat done)
    reg [7:0]  done_d  = 0;
    wire       rx_busy = (rstate != R_IDLE);

    always @(posedge CLK) begin
        done <= 1'b0;
        if (!RST) begin
            rstate <= R_IDLE; rcnt <= 0; rbit <= 0; rsh <= 0;
        end else case (rstate)
            R_IDLE: begin
                rcnt <= 0;
                if (!rxd_s) rstate <= R_START;      // tepi turun = start bit
            end
            R_START: begin                          // tunggu tengah start bit
                if (rcnt == half_m1) begin
                    rcnt <= 0;
                    if (!rxd_s) begin rbit <= 0; rstate <= R_DATA; end
                    else rstate <= R_IDLE;          // glitch, bukan start bit
                end else rcnt <= rcnt + 1'b1;
            end
            R_DATA: begin                           // sampel tiap 1 periode bit
                if (rcnt == div_m1) begin
                    rcnt <= 0;
                    rsh  <= {rxd_s, rsh[7:1]};      // LSB-first
                    if (rbit == 3'd7) rstate <= R_STOP;
                    else rbit <= rbit + 1'b1;
                end else rcnt <= rcnt + 1'b1;
            end
            R_STOP: begin
                if (rcnt == div_m1) begin
                    rcnt    <= 0;
                    done    <= 1'b1;
                    done_d  <= rsh;
                    done_fe <= ~rxd_s;              // stop bit harus 1
                    rstate  <= R_IDLE;
                end else rcnt <= rcnt + 1'b1;
            end
        endcase
    end

    // holding register 1 byte + flag (sama dengan uart_rx.v, termasuk fix pop
    // di siklus yang sama dengan snapshot RDATA)
    reg  [7:0] rx_data = 0;
    reg        rx_valid = 0, rx_ovr = 0, rx_ferr = 0;
    wire       rd_pop;

    always @(posedge CLK) begin
        if (!RST) begin
            rx_data <= 0; rx_valid <= 0; rx_ovr <= 0; rx_ferr <= 0;
        end else begin
            // byte baru menang atas clear di siklus yang sama (tidak hilang)
            if (rd_pop) begin rx_valid <= 0; rx_ovr <= 0; rx_ferr <= 0; end
            if (done) begin
                rx_data  <= done_d;
                rx_valid <= 1'b1;
                if (rx_valid && !rd_pop) rx_ovr <= 1'b1;
                if (done_fe) rx_ferr <= 1'b1;
            end
        end
    end

    wire [31:0] status = {27'b0, rx_busy, rx_ferr, rx_ovr, rx_valid, tx_busy};

    // ======================= AXI4-lite write =======================
    localparam AW_IDLE = 1'd0, AW_RESP = 1'd1;
    reg awstate = AW_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            awstate <= AW_IDLE; AWREADY <= 0; WREADY <= 0; BVALID <= 0;
            start_pulse <= 0; wdata_byte <= 0;
            div <= DIV_DEF; div_m1 <= DIV_DEF - 1; half_m1 <= DIV_DEF/2 - 1;
        end else begin
            start_pulse <= 1'b0;
            AWREADY <= 0;
            WREADY  <= 0;
            case (awstate)
                AW_IDLE: begin
                    BVALID <= 0;
                    if (AWVALID && WVALID) begin
                        AWREADY <= 1; WREADY <= 1; awstate <= AW_RESP;
                        case (AWADDR[1:0])
                            2'd0: if (!tx_busy) begin
                                wdata_byte  <= WDATA[7:0];
                                start_pulse <= 1'b1;
                            end
                            2'd3: if (WDATA[15:0] >= DIV_MIN && !tx_busy && !rx_busy) begin
                                div     <= WDATA[15:0];
                                div_m1  <= WDATA[15:0] - 1'b1;
                                half_m1 <= {1'b0, WDATA[15:1]} - 1'b1;
                            end
                            default: ;              // RXDATA/STATUS: abaikan
                        endcase
                    end
                end
                AW_RESP: begin
                    BVALID <= 1;
                    // gating pakai BVALID teregister, lihat uart_tx.v
                    if (BVALID && BREADY) begin BVALID <= 0; awstate <= AW_IDLE; end
                end
            endcase
        end
    end

    // ======================= AXI4-lite read =======================
    localparam AR_IDLE = 1'b0, AR_RESP = 1'b1;
    reg ar_state = AR_IDLE;
    // pop HANYA untuk RXDATA -- baca STATUS/TXDATA tidak boleh menghapus byte
    assign rd_pop = RST && (ar_state == AR_IDLE) && ARVALID && (ARADDR[1:0] == 2'd1);
    always @(posedge CLK) begin
        if (!RST) begin
            ar_state <= AR_IDLE; ARREADY <= 0; RVALID <= 0; RDATA <= 0;
        end else case (ar_state)
            AR_IDLE: begin
                RVALID <= 0;
                if (ARVALID) begin
                    ARREADY <= 1;
                    case (ARADDR[1:0])
                        2'd1:    RDATA <= {21'b0, rx_ferr, rx_ovr, rx_valid, rx_data};
                        2'd3:    RDATA <= {16'b0, div};
                        default: RDATA <= status;
                    endcase
                    ar_state <= AR_RESP;
                end
            end
            AR_RESP: begin
                ARREADY <= 0; RVALID <= 1;
                if (RVALID && RREADY) begin RVALID <= 0; ar_state <= AR_IDLE; end
            end
        endcase
    end
endmodule
