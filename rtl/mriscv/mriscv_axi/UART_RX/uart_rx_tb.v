`timescale 1ns / 1ps
// Testbench unit uart_rx: CLK_HZ/BAUD = 10 siklus/bit.
module uart_rx_tb;
    localparam CLK_HZ = 1000, BAUD = 100, BIT = 10;
    reg CLK = 0, RST = 0, RXD = 1;
    reg ARVALID = 0, RREADY = 0;
    wire ARREADY, RVALID; wire [31:0] RDATA;
    integer errors = 0;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .CLK(CLK), .RST(RST),
        .AWVALID(1'b0), .WVALID(1'b0), .BREADY(1'b0),
        .AWADDR(32'b0), .WDATA(32'b0), .WSTRB(4'b0),
        .AWREADY(), .WREADY(), .BVALID(),
        .ARVALID(ARVALID), .RREADY(RREADY), .ARADDR(32'b0),
        .ARREADY(ARREADY), .RVALID(RVALID), .RDATA(RDATA), .RXD(RXD));

    always #1 CLK = ~CLK;

    task send(input [7:0] b, input stop);
        integer i;
        begin
            RXD = 0; repeat (BIT) @(posedge CLK);
            for (i = 0; i < 8; i = i + 1) begin RXD = b[i]; repeat (BIT) @(posedge CLK); end
            RXD = stop; repeat (BIT) @(posedge CLK);
            RXD = 1;
        end
    endtask

    reg [31:0] v;
    task axi_read;
        begin
            @(posedge CLK); ARVALID <= 1;
            @(posedge CLK); wait (ARREADY); @(posedge CLK); ARVALID <= 0;
            RREADY <= 1; wait (RVALID); v = RDATA; @(posedge CLK); RREADY <= 0;
            repeat (3) @(posedge CLK);
        end
    endtask

    task check(input [31:0] exp, input [255:0] name);
        begin
            if (v !== exp) begin errors = errors + 1;
                $display("FAIL %0s: got %h expected %h", name, v, exp); end
            else $display("ok   %0s = %h", name, v);
        end
    endtask

    // Regresi race baca/terima: polling terus-menerus sambil menerima byte
    // berurutan. Byte yang selesai diterima tepat di siklus snapshot RDATA
    // dulu hilang tanpa flag overrun (pop satu siklus setelah snapshot). Offset
    // awal disapu supaya polling dan byte jatuh di semua fase relatif.
    reg polling = 0;
    integer got;
    reg [7:0] seq [0:15];
    task poll_loop;
        begin
            while (polling) begin
                axi_read;
                if (v[8]) begin seq[got] = v[7:0]; got = got + 1; end
                if (v[10:9] != 0) begin errors = errors + 1; $display("FAIL race: flag overrun/ferr = %b", v[10:9]); end
            end
        end
    endtask

    task race_test(input integer off);
        integer k;
        begin
            got = 0; polling = 1;
            fork
                poll_loop;
                begin
                    repeat (off) @(posedge CLK);
                    for (k = 0; k < 8; k = k + 1) send(8'h10 + k, 1);
                    repeat (30) @(posedge CLK);
                    polling = 0;
                end
            join
            axi_read; if (v[8]) begin seq[got] = v[7:0]; got = got + 1; end
            if (got !== 8) begin errors = errors + 1; $display("FAIL race offset %0d: %0d of 8 bytes", off, got); end
            else for (k = 0; k < 8; k = k + 1)
                if (seq[k] !== 8'h10 + k) begin errors = errors + 1; $display("FAIL race offset %0d: byte %0d = %h", off, k, seq[k]); end
        end
    endtask

    integer o;
    initial begin
        repeat (5) @(posedge CLK); RST = 1; repeat (5) @(posedge CLK);
        axi_read;                       check(32'h000, "kosong");
        send(8'hA5, 1);  repeat (4) @(posedge CLK);
        axi_read;                       check(32'h1A5, "byte A5");
        axi_read;                       check(32'h0A5, "baca ke-2: valid sudah clear");
        send(8'h00, 1);  send(8'hFF, 1); repeat (4) @(posedge CLK);
        axi_read;                       check(32'h3FF, "overrun: FF menimpa 00");
        axi_read;                       check(32'h0FF, "flag overrun clear");
        send(8'h3C, 0);  repeat (4) @(posedge CLK);
        axi_read;                       check(32'h53C, "framing error");
        // glitch pendek (< setengah bit) harus diabaikan
        RXD = 0; repeat (3) @(posedge CLK); RXD = 1; repeat (3*BIT) @(posedge CLK);
        axi_read;                       check(32'h03C, "glitch diabaikan");
        // byte berurutan tanpa jeda
        send(8'h55, 1); send(8'h0F, 1); repeat (4) @(posedge CLK);
        axi_read;                       check(32'h30F, "back-to-back (55 tertimpa, overrun)");
        axi_read;                       // kosongkan
        for (o = 0; o < 12; o = o + 1) race_test(o);
        $display("race baca/terima: 12 offset x 8 byte diperiksa");
        if (errors == 0) $display("PASS"); else $display("FAILED: %0d error", errors);
        $finish;
    end
    initial begin #200000 $display("TIMEOUT"); $finish; end
endmodule
