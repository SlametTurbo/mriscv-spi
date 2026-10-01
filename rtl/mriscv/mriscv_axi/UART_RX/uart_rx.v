`timescale 1ns / 1ps
// ============================================================================
// uart_rx.v -- UART RX-only, slave AXI4-lite. 8N1, LSB-first, baud tetap.
//
// BACA (alamat manapun dalam range slave ini):
//   RDATA[7:0]  = byte terakhir yang diterima
//   RDATA[8]    = valid   (1 = ada byte baru yang belum dibaca)
//   RDATA[9]    = overrun (1 = ada byte yang ditimpa sebelum sempat dibaca)
//   RDATA[10]   = ferr    (1 = stop bit bukan '1' pada salah satu byte)
// Membaca MENGHAPUS valid/overrun/ferr (satu baca = satu "pop"). Firmware
// cukup polling: v = UART_RX; if (v & 0x100) c = v & 0xFF;
// TULIS diterima & diabaikan (selalu cepat, non-blocking, seperti uart_tx).
//
// Holding register cuma 1 byte: pada 115200 baud 1 byte = ~4340 siklus @50MHz,
// jadi loop polling yang wajar tidak kehilangan data; kalau firmware sibuk
// lama (mis. delay panjang) byte berikutnya menimpa dan overrun di-set.
//
// Baud dihitung dari CLK_HZ/BAUD -- kalau clock core diubah, CLK_HZ di
// instansiasi WAJIB disesuaikan (sama seperti uart_tx).
// ============================================================================
module uart_rx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115200
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

    input             RXD
);
    localparam integer DIV  = CLK_HZ / BAUD;
    localparam integer DIVW = $clog2(DIV);

    // ---- sinkronizer 2-FF (RXD asinkron terhadap CLK) ----
    reg rxd_m = 1'b1, rxd_s = 1'b1;
    always @(posedge CLK) begin rxd_m <= RXD; rxd_s <= rxd_m; end

    // ---- receiver engine ----
    localparam R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2, R_STOP = 2'd3;
    reg [1:0]      rstate  = R_IDLE;
    reg [DIVW-1:0] baudcnt = 0;
    reg [2:0]      bitidx  = 0;
    reg [7:0]      shreg   = 0;

    reg       done   = 1'b0;   // pulsa 1 siklus saat 1 byte selesai diterima
    reg       done_fe = 1'b0;  // stop bit salah (valid saat done=1)
    reg [7:0] done_d = 0;

    always @(posedge CLK) begin
        done <= 1'b0;
        if (!RST) begin
            rstate <= R_IDLE; baudcnt <= 0; bitidx <= 0; shreg <= 0;
        end else case (rstate)
            R_IDLE: begin
                baudcnt <= 0;
                if (!rxd_s) rstate <= R_START;      // tepi turun = start bit
            end
            R_START: begin                          // tunggu tengah start bit
                if (baudcnt == (DIV/2)-1) begin
                    baudcnt <= 0;
                    if (!rxd_s) begin bitidx <= 0; rstate <= R_DATA; end
                    else rstate <= R_IDLE;          // glitch, bukan start bit
                end else baudcnt <= baudcnt + 1'b1;
            end
            R_DATA: begin                           // sampel tiap 1 periode baud
                if (baudcnt == DIV-1) begin
                    baudcnt <= 0;
                    shreg   <= {rxd_s, shreg[7:1]}; // LSB-first
                    if (bitidx == 3'd7) rstate <= R_STOP;
                    else bitidx <= bitidx + 1'b1;
                end else baudcnt <= baudcnt + 1'b1;
            end
            R_STOP: begin
                if (baudcnt == DIV-1) begin
                    baudcnt <= 0;
                    done    <= 1'b1;
                    done_d  <= shreg;
                    done_fe <= ~rxd_s;              // stop bit harus 1
                    rstate  <= R_IDLE;
                end else baudcnt <= baudcnt + 1'b1;
            end
        endcase
    end

    // ---- holding register + flag ----
    reg [7:0] rx_data = 0;
    reg       rx_valid = 0, rx_ovr = 0, rx_ferr = 0;
    // Pop terjadi di siklus yang SAMA dengan snapshot RDATA (kombinasional dari
    // read FSM). Versi lama meng-clear satu siklus SETELAH snapshot: byte yang
    // selesai diterima tepat di siklus snapshot tidak ikut ter-snapshot, lalu
    // valid-nya ter-clear oleh pop -> byte hilang tanpa flag overrun (terlihat
    // sebagai frame yang kurang 1-2 byte di sha_demo).
    wire      rd_pop;

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

    // ---- AXI4-lite write FSM: terima & abaikan, selalu cepat ----
    localparam AW_IDLE = 1'd0, AW_RESP = 1'd1;
    reg awstate = AW_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            awstate <= AW_IDLE; AWREADY <= 0; WREADY <= 0; BVALID <= 0;
        end else begin
            AWREADY <= 0;
            WREADY  <= 0;
            case (awstate)
                AW_IDLE: begin
                    BVALID <= 0;
                    if (AWVALID && WVALID) begin
                        AWREADY <= 1; WREADY <= 1; awstate <= AW_RESP;
                    end
                end
                AW_RESP: begin
                    BVALID <= 1;
                    if (BVALID && BREADY) begin BVALID <= 0; awstate <= AW_IDLE; end
                end
            endcase
        end
    end

    // ---- AXI4-lite read FSM: RDATA = {ferr, ovr, valid, data}; baca = pop ----
    localparam AR_IDLE = 1'b0, AR_RESP = 1'b1;
    reg ar_state = AR_IDLE;
    assign rd_pop = RST && (ar_state == AR_IDLE) && ARVALID;
    always @(posedge CLK) begin
        if (!RST) begin
            ar_state <= AR_IDLE; ARREADY <= 0; RVALID <= 0; RDATA <= 0;
        end else case (ar_state)
            AR_IDLE: begin
                RVALID <= 0;
                if (ARVALID) begin
                    ARREADY  <= 1;
                    RDATA    <= {21'b0, rx_ferr, rx_ovr, rx_valid, rx_data};
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
