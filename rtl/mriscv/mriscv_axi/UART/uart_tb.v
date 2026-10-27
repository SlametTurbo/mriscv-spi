`timescale 1ns / 1ps
// Testbench unit uart (TX+RX + register BAUDDIV). CLK_HZ/BAUD = 20 siklus/bit
// setelah reset. Cara jalan (dari root repo):
//   iverilog -g2012 -o build/uart_tb.vvp rtl/mriscv/mriscv_axi/UART/uart_tb.v \
//       rtl/mriscv/mriscv_axi/UART/uart.v && vvp build/uart_tb.vvp
module uart_tb;
    localparam CLK_HZ = 2000, BAUD = 100;    // DIV awal = 20
    reg CLK = 0, RST = 0, RXD = 1;
    reg AWVALID = 0, WVALID = 0, BREADY = 0, ARVALID = 0, RREADY = 0;
    reg [31:0] AWADDR = 0, WDATA = 0, ARADDR = 0;
    wire AWREADY, WREADY, BVALID, ARREADY, RVALID, TXD;
    wire [31:0] RDATA;
    integer errors = 0;

    uart #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .CLK(CLK), .RST(RST),
        .AWVALID(AWVALID), .WVALID(WVALID), .BREADY(BREADY),
        .AWADDR(AWADDR), .WDATA(WDATA), .WSTRB(4'hF),
        .AWREADY(AWREADY), .WREADY(WREADY), .BVALID(BVALID),
        .ARVALID(ARVALID), .RREADY(RREADY), .ARADDR(ARADDR),
        .ARREADY(ARREADY), .RVALID(RVALID), .RDATA(RDATA),
        .TXD(TXD), .RXD(RXD));

    always #1 CLK = ~CLK;

    localparam TXDATA = 0, RXDATA = 1, STATUS = 2, BAUDDIV = 3;

    // ---------------- AXI master ----------------
    task axi_write(input [1:0] r, input [31:0] d);
        integer t;
        begin
            @(posedge CLK); AWADDR <= 32'h4020 | r; WDATA <= d;
            AWVALID <= 1; WVALID <= 1; BREADY <= 1;
            t = 0; while (!(AWREADY && WREADY) && t < 50) begin @(posedge CLK); t = t + 1; end
            AWVALID <= 0; WVALID <= 0;
            t = 0; while (!BVALID && t < 50) begin @(posedge CLK); t = t + 1; end
            @(posedge CLK); BREADY <= 0;
            if (t >= 50) begin errors = errors + 1; $display("FAIL axi_write r%0d macet", r); end
        end
    endtask

    reg [31:0] v;
    task axi_read(input [1:0] r);
        begin
            @(posedge CLK); ARADDR <= 32'h4020 | r; ARVALID <= 1;
            @(posedge CLK); wait (ARREADY); @(posedge CLK); ARVALID <= 0;
            RREADY <= 1; wait (RVALID); v = RDATA; @(posedge CLK); RREADY <= 0;
            repeat (2) @(posedge CLK);
        end
    endtask

    task check(input [31:0] exp, input [511:0] name);
        begin
            if (v !== exp) begin errors = errors + 1;
                $display("FAIL %0s: dapat %h, harap %h", name, v, exp); end
            else $display("ok   %0s = %h", name, v);
        end
    endtask

    // ---------------- host -> RXD ----------------
    task send(input [7:0] b, input stop, input integer bitw);
        integer i;
        begin
            RXD = 0; repeat (bitw) @(posedge CLK);
            for (i = 0; i < 8; i = i + 1) begin RXD = b[i]; repeat (bitw) @(posedge CLK); end
            RXD = stop; repeat (bitw) @(posedge CLK);
            RXD = 1;
        end
    endtask

    // ---------------- monitor TXD (decoder independen, lebar bit dari tb) ----------------
    integer tx_bitw = 20;
    integer ntx = 0;
    reg [7:0] txq [0:15];
    reg       txfe [0:15];
    initial begin : txmon
        integer i; reg [7:0] b;
        forever begin
            @(negedge TXD);
            repeat (tx_bitw/2) @(posedge CLK);
            if (TXD !== 1'b0) begin errors = errors + 1; $display("FAIL TX start bit bukan 0"); end
            for (i = 0; i < 8; i = i + 1) begin repeat (tx_bitw) @(posedge CLK); b[i] = TXD; end
            repeat (tx_bitw) @(posedge CLK);
            txq[ntx] = b; txfe[ntx] = (TXD !== 1'b1); ntx = ntx + 1;
        end
    end

    task expect_tx(input [7:0] b, input [511:0] name);
        integer t;
        begin
            t = 0; while (ntx == 0 && t < 2000) begin @(posedge CLK); t = t + 1; end
            if (ntx != 1 || txq[0] !== b || txfe[0]) begin
                errors = errors + 1;
                $display("FAIL %0s: ntx=%0d byte=%h fe=%b, harap %h", name, ntx, txq[0], txfe[0], b);
            end else $display("ok   %0s: TX %h", name, b);
            ntx = 0;
        end
    endtask

    task wait_tx_idle;
        begin v = 1; while (v[0]) axi_read(STATUS); repeat (tx_bitw) @(posedge CLK); end
    endtask

    initial begin
        repeat (5) @(posedge CLK); RST = 1; repeat (5) @(posedge CLK);

        // ---- reset ----
        axi_read(BAUDDIV); check(32'd20, "BAUDDIV awal");
        axi_read(STATUS);  check(32'h0,  "STATUS awal");

        // ---- TX @ DIV 20, tulis saat busy diabaikan, baca +0 = status ----
        axi_write(TXDATA, 32'hA5);
        axi_read(TXDATA);  check(32'h1, "baca TXDATA saat kirim (tx_busy)");
        axi_write(TXDATA, 32'h33);                  // harus diabaikan
        repeat (12*20) @(posedge CLK);
        expect_tx(8'hA5, "TX div20 + tulis saat busy diabaikan");

        // ---- RX @ DIV 20: STATUS tidak pop, RXDATA pop ----
        send(8'h3C, 1, 20); repeat (5) @(posedge CLK);
        axi_read(STATUS);  check(32'h2,   "STATUS rx_valid");
        axi_read(STATUS);  check(32'h2,   "STATUS dibaca 2x tetap valid (tidak pop)");
        axi_read(RXDATA);  check(32'h13C, "RXDATA pop");
        axi_read(RXDATA);  check(32'h03C, "RXDATA setelah pop (valid=0)");

        // ---- overrun & framing error ----
        send(8'h11, 1, 20); send(8'h22, 1, 20); repeat (5) @(posedge CLK);
        axi_read(STATUS);  check(32'h6,   "STATUS overrun");
        axi_read(RXDATA);  check(32'h322, "RXDATA overrun");
        send(8'h44, 0, 20); repeat (25) @(posedge CLK);
        axi_read(RXDATA);  check(32'h544, "RXDATA ferr");

        // ---- tulis BAUDDIV: di bawah minimum ditolak ----
        axi_write(BAUDDIV, 32'd15);
        axi_read(BAUDDIV); check(32'd20, "BAUDDIV=15 ditolak (< DIV_MIN)");
        axi_write(BAUDDIV, 32'd16);
        axi_read(BAUDDIV); check(32'd16, "BAUDDIV=16 diterima");

        // ---- ditolak saat tx_busy ----
        tx_bitw = 16;
        axi_write(TXDATA, 32'h5A);
        axi_write(BAUDDIV, 32'd40);
        axi_read(BAUDDIV); check(32'd16, "BAUDDIV ditolak saat tx_busy");
        repeat (11*16) @(posedge CLK);
        expect_tx(8'h5A, "TX div16");

        // ---- ditolak saat rx_busy ----
        fork
            send(8'h77, 1, 16);
            begin repeat (40) @(posedge CLK); axi_write(BAUDDIV, 32'd40); end
        join
        axi_read(BAUDDIV); check(32'd16,  "BAUDDIV ditolak saat rx_busy");
        axi_read(RXDATA);  check(32'h177, "RX div16 tetap utuh");

        // ---- ganti ke 37 (ganjil), TX + RX di baud baru ----
        axi_write(BAUDDIV, 32'd37);
        axi_read(BAUDDIV); check(32'd37, "BAUDDIV=37");
        tx_bitw = 37;
        axi_write(TXDATA, 32'hC3);
        repeat (11*37) @(posedge CLK);
        expect_tx(8'hC3, "TX div37");
        send(8'h96, 1, 37); repeat (5) @(posedge CLK);
        axi_read(RXDATA);  check(32'h196, "RX div37");
        // host masih di baud lama (20) -> byte rusak / ferr, bukti div dipakai RX
        send(8'h96, 1, 20); repeat (40*10) @(posedge CLK);
        axi_read(RXDATA);
        if (v[8] && v[7:0] == 8'h96 && !v[10]) begin
            errors = errors + 1; $display("FAIL RX baud salah tetap diterima benar (%h)", v);
        end else $display("ok   RX dengan baud salah tidak diterima utuh (%h)", v);
        repeat (40*12) @(posedge CLK); axi_read(RXDATA);   // buang sisa

        // ---- TX dan RX bersamaan (full duplex) ----
        fork
            axi_write(TXDATA, 32'h0F);
            send(8'hF0, 1, 37);
        join
        repeat (5) @(posedge CLK);
        axi_read(RXDATA);  check(32'h1F0, "full duplex RX");
        expect_tx(8'h0F, "full duplex TX");

        // ---- reset mengembalikan BAUDDIV ke default ----
        RST = 0; repeat (3) @(posedge CLK); RST = 1; repeat (3) @(posedge CLK);
        axi_read(BAUDDIV); check(32'd20, "BAUDDIV setelah reset");

        if (errors == 0) $display("HASIL: PASS");
        else             $display("HASIL: FAIL (%0d kesalahan)", errors);
        $finish;
    end

    initial begin #2000000; $display("FAIL timeout"); $finish; end
endmodule
