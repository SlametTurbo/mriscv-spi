`timescale 1ns / 1ps
// ============================================================================
// i2c_master.v -- I2C master level-byte, slave AXI4-lite. Satu modul, satu FSM.
//
// REGISTER (dipilih lewat ADDR[1:0] = indeks word di dalam slave):
//   0 DATA   tulis: byte yang akan dikirim      baca: byte terakhir diterima
//   1 CMD    tulis: bit0 START  bit1 STOP  bit2 WRITE  bit3 READ  bit4 NACK
//            Satu tulis = satu operasi, urutan tetap:
//              [START/repeated START] -> [kirim DATA | terima byte] -> [STOP]
//            NACK (hanya untuk READ): kirim NACK setelah byte (byte terakhir).
//   2 STATUS baca: bit0 busy   bit1 nack (1 = slave tidak ACK, hasil WRITE)
//                  bit2 arb_lost (SDA ditarik slave/master lain saat kirim '1')
//   3 DIV    tulis/baca: clk per seperempat periode SCL (minimal 4, saat idle)
//
// Semantik NON-BLOCKING seperti uart_tx: tulis AXI selalu cepat. Tulis DATA/CMD/
// DIV saat busy diabaikan diam-diam, jadi firmware polling busy dulu.
//
// Pin open-drain: *_O = 1 artinya LEPAS (bus ditarik pull-up), 0 = tarik low.
// SCL_I dipakai untuk clock stretching, SDA_I untuk ACK/baca/arbitrasi.
// ============================================================================
module i2c_master #(
    parameter CLK_HZ = 50_000_000,
    parameter I2C_HZ = 400_000
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

    input             SCL_I, input SDA_I,
    output reg        SCL_O, output reg SDA_O
);
    localparam [15:0] DIV_DEF = CLK_HZ / (4 * I2C_HZ);

    // ---- sinkronizer 2-FF untuk input bus ----
    reg scl_m = 1'b1, scl_s = 1'b1, sda_m = 1'b1, sda_s = 1'b1;
    always @(posedge CLK) begin
        scl_m <= SCL_I; scl_s <= scl_m;
        sda_m <= SDA_I; sda_s <= sda_m;
    end

    // ---- register yang ditulis dari sisi AXI ----
    reg [7:0]  tx_data = 0;
    reg [15:0] div     = DIV_DEF;
    reg        cmd_go  = 1'b0;          // pulsa 1 siklus: mulai operasi
    reg        f_start = 0, f_stop = 0, f_write = 0, f_read = 0, f_nack = 0;

    // ---- engine ----
    localparam S_IDLE = 3'd0, S_START = 3'd1, S_TX = 3'd2, S_ACKR = 3'd3,
               S_RX   = 3'd4, S_ACKT  = 3'd5, S_STOP = 3'd6;
    reg [2:0]  state = S_IDLE;
    reg [1:0]  ph    = 0;               // seperempat periode SCL
    reg [2:0]  bitn  = 0;
    reg [7:0]  sh    = 0;
    reg [15:0] tcnt  = 0;
    reg [7:0]  rx_data = 0;
    reg        nack_r = 0, arb_r = 0;

    wire busy = (state != S_IDLE) || cmd_go;
    wire tick = (tcnt == div - 1'b1);
    // Saat kita MELEPAS SCL, maju hanya kalau SCL benar-benar high
    // (clock stretching oleh slave).
    wire adv  = tick && (!SCL_O || scl_s);

    always @(posedge CLK) begin
        if (!RST) begin
            state <= S_IDLE; ph <= 0; bitn <= 0; sh <= 0; tcnt <= 0;
            rx_data <= 0; nack_r <= 0; arb_r <= 0;
            SCL_O <= 1'b1; SDA_O <= 1'b1;
        end else begin
            tcnt <= tick ? 16'd0 : tcnt + 1'b1;
            if (cmd_go) begin
                nack_r <= 0; arb_r <= 0;
                ph <= 0; bitn <= 3'd7; sh <= tx_data; tcnt <= 0;
                if (f_start)      state <= S_START;
                else if (f_write) state <= S_TX;
                else if (f_read)  state <= S_RX;
                else if (f_stop)  state <= S_STOP;
            end else if (state != S_IDLE && adv) begin
                ph <= ph + 1'b1;
                case (state)
                S_START: case (ph)
                    2'd0: SDA_O <= 1'b1;
                    2'd1: SCL_O <= 1'b1;
                    2'd2: SDA_O <= 1'b0;                 // START: SDA turun saat SCL high
                    2'd3: begin
                        SCL_O <= 1'b0;
                        state <= f_write ? S_TX : f_read ? S_RX :
                                 f_stop  ? S_STOP : S_IDLE;
                    end
                endcase
                S_TX: case (ph)
                    2'd0: SDA_O <= sh[7];
                    2'd1: SCL_O <= 1'b1;
                    2'd2: if (sh[7] && !sda_s) begin     // arbitrasi hilang
                              arb_r <= 1'b1; state <= S_IDLE;
                              SCL_O <= 1'b1; SDA_O <= 1'b1;
                          end
                    2'd3: begin
                        SCL_O <= 1'b0;
                        sh <= {sh[6:0], 1'b0};
                        bitn <= bitn - 1'b1;
                        if (bitn == 3'd0) state <= S_ACKR;
                    end
                endcase
                S_ACKR: case (ph)
                    2'd0: SDA_O <= 1'b1;
                    2'd1: SCL_O <= 1'b1;
                    2'd2: nack_r <= sda_s;               // ACK = SDA low
                    2'd3: begin
                        SCL_O <= 1'b0;
                        state <= f_stop ? S_STOP : S_IDLE;
                    end
                endcase
                S_RX: case (ph)
                    2'd0: SDA_O <= 1'b1;
                    2'd1: SCL_O <= 1'b1;
                    2'd2: sh <= {sh[6:0], sda_s};
                    2'd3: begin
                        SCL_O <= 1'b0;
                        bitn <= bitn - 1'b1;
                        if (bitn == 3'd0) begin rx_data <= sh; state <= S_ACKT; end
                    end
                endcase
                S_ACKT: case (ph)
                    2'd0: SDA_O <= f_nack;
                    2'd1: SCL_O <= 1'b1;
                    2'd2: ;
                    2'd3: begin
                        SCL_O <= 1'b0;
                        state <= f_stop ? S_STOP : S_IDLE;
                    end
                endcase
                S_STOP: case (ph)
                    2'd0: SDA_O <= 1'b0;
                    2'd1: SCL_O <= 1'b1;
                    2'd2: SDA_O <= 1'b1;                 // STOP: SDA naik saat SCL high
                    2'd3: state <= S_IDLE;
                endcase
                default: state <= S_IDLE;
                endcase
            end
        end
    end

    // ---- AXI4-lite write FSM: register write, selalu cepat ----
    localparam AW_IDLE = 1'd0, AW_RESP = 1'd1;
    reg awstate = AW_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            awstate <= AW_IDLE; AWREADY <= 0; WREADY <= 0; BVALID <= 0;
            cmd_go <= 0; tx_data <= 0; div <= DIV_DEF;
            f_start <= 0; f_stop <= 0; f_write <= 0; f_read <= 0; f_nack <= 0;
        end else begin
            AWREADY <= 0;
            WREADY  <= 0;
            cmd_go  <= 0;
            case (awstate)
                AW_IDLE: begin
                    BVALID <= 0;
                    if (AWVALID && WVALID) begin
                        AWREADY <= 1; WREADY <= 1; awstate <= AW_RESP;
                        if (!busy) case (AWADDR[1:0])
                            2'd0: tx_data <= WDATA[7:0];
                            2'd1: begin
                                f_start <= WDATA[0]; f_stop <= WDATA[1];
                                f_write <= WDATA[2]; f_read <= WDATA[3];
                                f_nack  <= WDATA[4];
                                cmd_go  <= 1'b1;
                            end
                            2'd3: if (WDATA[15:0] >= 16'd4) div <= WDATA[15:0];
                            default: ;
                        endcase
                    end
                end
                AW_RESP: begin
                    BVALID <= 1;
                    if (BVALID && BREADY) begin BVALID <= 0; awstate <= AW_IDLE; end
                end
            endcase
        end
    end

    // ---- AXI4-lite read FSM ----
    localparam AR_IDLE = 1'b0, AR_RESP = 1'b1;
    reg ar_state = AR_IDLE;
    always @(posedge CLK) begin
        if (!RST) begin
            ar_state <= AR_IDLE; ARREADY <= 0; RVALID <= 0; RDATA <= 0;
        end else case (ar_state)
            AR_IDLE: begin
                RVALID <= 0;
                if (ARVALID) begin
                    ARREADY <= 1;
                    case (ARADDR[1:0])
                        2'd0:    RDATA <= {24'b0, rx_data};
                        2'd1:    RDATA <= {27'b0, f_nack, f_read, f_write, f_stop, f_start};
                        2'd2:    RDATA <= {29'b0, arb_r, nack_r, busy};
                        default: RDATA <= {16'b0, div};
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
