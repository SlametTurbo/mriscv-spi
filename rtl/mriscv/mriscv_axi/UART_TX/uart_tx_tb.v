`timescale 1ns / 1ps
// Testbench fungsional uart_tx.v: kirim AXI write, decode ulang bit TXD manual
// (start/data-LSB-first/stop), bandingkan ke byte yang ditulis. DIV kecil biar
// simulasi cepat -- baud/clock rasio sama persis dengan hardware (~DIV=5208
// utk 50MHz/9600), cuma skala waktu dipercepat.
module uart_tx_tb;
    localparam CLK_HZ = 1000, BAUD = 100; // DIV = 10 siklus/bit
    reg CLK = 0, RST = 0;
    reg AWVALID = 0, WVALID = 0, BREADY = 0;
    reg [31:0] AWADDR = 0, WDATA = 0;
    reg [3:0]  WSTRB = 4'hF;
    wire AWREADY, WREADY, BVALID;
    reg ARVALID = 0, RREADY = 0;
    reg [31:0] ARADDR = 0;
    wire ARREADY, RVALID;
    wire [31:0] RDATA;
    wire TXD;

    integer errors = 0;
    reg dbg = 0;
    always @(posedge CLK) if (dbg) $display("  [dbg t=%0t] awstate=%0d tstate=%0d busy=%b start_pulse=%b wdata_byte=%02h AWVALID=%b WVALID=%b AWREADY=%b WREADY=%b BVALID=%b BREADY=%b",
        $time, dut.awstate, dut.tstate, dut.busy, dut.start_pulse, dut.wdata_byte, AWVALID, WVALID, AWREADY, WREADY, BVALID, BREADY);

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .CLK(CLK), .RST(RST),
        .AWVALID(AWVALID), .WVALID(WVALID), .BREADY(BREADY),
        .AWADDR(AWADDR), .WDATA(WDATA), .WSTRB(WSTRB),
        .AWREADY(AWREADY), .WREADY(WREADY), .BVALID(BVALID),
        .ARVALID(ARVALID), .RREADY(RREADY), .ARADDR(ARADDR),
        .ARREADY(ARREADY), .RVALID(RVALID), .RDATA(RDATA),
        .TXD(TXD)
    );

    always #1 CLK = ~CLK; // period 2ns -> 10 siklus/bit = 20ns/bit

    task axi_write(input [7:0] b);
        begin
            @(posedge CLK);
            AWVALID <= 1; WVALID <= 1; WDATA <= {24'b0, b};
            @(posedge CLK);
            wait (AWREADY && WREADY);
            @(posedge CLK);
            AWVALID <= 0; WVALID <= 0;
            BREADY <= 1;
            wait (BVALID);
            @(posedge CLK);
            BREADY <= 0;
        end
    endtask

    // decode 1 byte langsung dari garis TXD (idle=1, start=0, 8 data LSB-first, stop=1)
    task uart_capture(output [7:0] got);
        integer i;
        begin
            wait (TXD == 1'b0);              // start bit
            #(10 * 2 * 1.5);                  // maju ke tengah bit data pertama (1.5 bit period)
            for (i = 0; i < 8; i = i + 1) begin
                got[i] = TXD;
                #(10 * 2);                    // 1 bit period = 20ns
            end
            if (TXD !== 1'b1) begin
                $display("FAIL: stop bit bukan 1 (got=%b)", TXD);
                errors = errors + 1;
            end
        end
    endtask

    reg [7:0] captured;
    initial begin
        RST = 0;
        repeat (3) @(posedge CLK);
        RST = 1;

        // Test 1: kirim 0xA5, verifikasi via capture paralel
        fork
            axi_write(8'hA5);
            begin
                uart_capture(captured);
                if (captured !== 8'hA5) begin
                    $display("FAIL test1: expected A5, got %02h", captured);
                    errors = errors + 1;
                end else $display("PASS test1: 0xA5 captured correctly");
            end
        join

        // Test 2: line harus idle-high sesaat setelah stop bit
        repeat (5) @(posedge CLK);
        if (TXD !== 1'b1) begin
            $display("FAIL test2: TXD tidak idle high setelah transmit");
            errors = errors + 1;
        end else $display("PASS test2: TXD idle high");

        // Test 3: write kedua saat idle -> harus langsung mulai transmit lagi
        fork
            axi_write(8'h00);
            begin
                uart_capture(captured);
                if (captured !== 8'h00) begin
                    $display("FAIL test3: expected 00, got %02h", captured);
                    errors = errors + 1;
                end else $display("PASS test3: 0x00 captured correctly");
            end
        join

        // uart_capture() selesai berdasarkan sampling manual per-bit yg bisa
        // resolve SEDIKIT lebih awal daripada tstate RTL benar2 balik ke
        // S_IDLE (beda beberapa siklus di ujung stop-bit) -- tunggu busy
        // beneran clear dulu biar test4 mulai dari kondisi idle yang valid.
        wait (!dut.busy);
        repeat (3) @(posedge CLK);

        // Test 4: write KEDUA yang menyusul SAAT MASIH BUSY harus (a) tetap
        // selesai CEPAT di level AXI (non-blocking, BUKAN ditunda), dan
        // (b) byte KEDUA itu diam-diam DIABAIKAN (bukan di-queue) -- cuma
        // byte PERTAMA (0xFF) yang benar2 terkirim di garis TXD.
        begin : test4_block
            reg [31:0] t_before, t_after;
            axi_write(8'hFF);              // mulai transmit 0xFF (busy jadi 1)
            t_before = $time;
            axi_write(8'h3C);              // ditulis SAAT MASIH BUSY
            t_after = $time;
            if ((t_after - t_before) > 40) begin // jauh < 1 bit period (20ns)*sekian
                $display("FAIL test4a: write kedua saat busy ternyata LAMBAT (%0d ns) -- berarti masih blocking, bukan non-blocking", t_after - t_before);
                errors = errors + 1;
            end else $display("PASS test4a: write kedua saat busy selesai cepat (%0d ns) -- non-blocking terbukti benar", t_after - t_before);

            uart_capture(captured);        // baca 1 byte yang benar2 keluar di TXD
            if (captured !== 8'hFF) begin
                $display("FAIL test4b: expected FF (byte kedua harusnya di-drop), got %02h", captured);
                errors = errors + 1;
            end else $display("PASS test4b: cuma 0xFF yang terkirim, 0x3C benar2 di-drop diam-diam");

            // pastikan TIDAK ada transmisi kedua menyusul (garis harus idle-high terus)
            repeat (30) @(posedge CLK);
            if (TXD !== 1'b1) begin
                $display("FAIL test4c: ada transmisi tak terduga setelah byte pertama");
                errors = errors + 1;
            end else $display("PASS test4c: tidak ada transmisi susulan (0x3C benar2 hilang, bukan ke-queue)");
        end

        if (errors == 0) $display("=== ALL TESTS PASSED ===");
        else $display("=== %0d TEST(S) FAILED ===", errors);
        $finish;
    end

    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
