`timescale 1ns / 1ps
// Testbench unit i2c_master + model slave I2C (alamat 7-bit 0x3C) dengan
// clock stretching pada ACK alamat. Menguji: START/WRITE/STOP, NACK alamat
// salah, READ ACK/NACK, repeated START, stretching, dan arbitrasi hilang.
module i2c_master_tb;
    reg CLK = 0, RST = 0;
    always #10 CLK = ~CLK;                       // 50 MHz

    reg AWVALID=0, WVALID=0, BREADY=1, ARVALID=0, RREADY=1;
    reg [31:0] AWADDR=0, WDATA=0, ARADDR=0;
    wire AWREADY, WREADY, BVALID, ARREADY, RVALID;
    wire [31:0] RDATA;

    tri1 scl, sda;
    wire scl_o, sda_o;
    assign scl = scl_o ? 1'bz : 1'b0;
    assign sda = sda_o ? 1'bz : 1'b0;

    i2c_master dut (.CLK(CLK), .RST(RST),
        .AWVALID(AWVALID), .WVALID(WVALID), .BREADY(BREADY),
        .AWADDR(AWADDR), .WDATA(WDATA), .WSTRB(4'hF),
        .AWREADY(AWREADY), .WREADY(WREADY), .BVALID(BVALID),
        .ARVALID(ARVALID), .RREADY(RREADY), .ARADDR(ARADDR),
        .ARREADY(ARREADY), .RVALID(RVALID), .RDATA(RDATA),
        .SCL_I(scl), .SDA_I(sda), .SCL_O(scl_o), .SDA_O(sda_o));

    // ---------------- helper AXI ----------------
    task axi_write(input [31:0] a, input [31:0] d);
    begin
        @(posedge CLK); AWADDR<=a; WDATA<=d; AWVALID<=1; WVALID<=1;
        @(posedge CLK); while (!AWREADY) @(posedge CLK);
        AWVALID<=0; WVALID<=0;
        @(posedge CLK); while (!BVALID) @(posedge CLK);
    end
    endtask
    reg [31:0] rd;
    task axi_read(input [31:0] a);
    begin
        @(posedge CLK); ARADDR<=a; ARVALID<=1;
        @(posedge CLK); while (!ARREADY) @(posedge CLK);
        ARVALID<=0;
        @(posedge CLK); while (!RVALID) @(posedge CLK);
        rd = RDATA;
    end
    endtask
    task wait_idle;
    begin
        axi_read(2);
        while (rd[0]) axi_read(2);
    end
    endtask
    // CMD: bit0 START bit1 STOP bit2 WRITE bit3 READ bit4 NACK
    task op(input [4:0] cmd, input [7:0] data);
    begin
        if (cmd[2]) axi_write(0, data);
        axi_write(1, cmd);
        wait_idle;
    end
    endtask

    // ---------------- model slave ----------------
    reg sda_s_o = 1, stretch = 0;
    assign sda = sda_s_o ? 1'bz : 1'b0;
    assign scl = stretch ? 1'b0 : 1'bz;
    reg start_p = 0, stop_p = 0;
    reg [7:0] got [0:15]; integer ngot = 0;
    integer nstop = 0, nstart = 0;
    reg [7:0] rdtab [0:3];
    integer rdi = 0;
    initial begin rdtab[0]=8'hA5; rdtab[1]=8'h5A; rdtab[2]=8'hC3; rdtab[3]=8'h3C; end

    always @(negedge sda) if (scl === 1'b1) begin
        nstart = nstart + 1; start_p = 1; #1 start_p = 0;
    end
    always @(posedge sda) if (scl === 1'b1) begin
        nstop = nstop + 1; stop_p = 1; #1 stop_p = 0;
    end

    reg [7:0] b; reg aborted; integer i;
    task recv_byte;
    begin
        aborted = 0; b = 0;
        for (i = 0; i < 8 && !aborted; i = i + 1) begin
            @(posedge scl or posedge stop_p or posedge start_p);
            if (stop_p || start_p) aborted = 1;
            else b = {b[6:0], sda};
        end
    end
    endtask

    reg rw, nack_m, restart;
    initial begin
        forever begin
            @(posedge start_p);
            restart = 1;
            while (restart) begin
                restart = 0;
                recv_byte;
                if (aborted) begin
                    if (start_p) restart = 1;
                end else if (b[7:1] != 7'h3C) begin
                    // alamat salah: tidak ACK, tunggu stop/start
                    @(negedge scl);
                    @(posedge stop_p or posedge start_p);
                    if (start_p) restart = 1;
                end else begin
                    rw = b[0];
                    @(negedge scl);
                    stretch = 1; sda_s_o = 0;           // ACK + tahan SCL
                    #2000 stretch = 0;
                    @(posedge scl); @(negedge scl);
                    if (!rw) begin
                        sda_s_o = 1;
                        aborted = 0;
                        got[ngot] = b; ngot = ngot + 1;
                        while (!aborted) begin
                            recv_byte;
                            if (aborted) begin if (start_p) restart = 1; end
                            else begin
                                got[ngot] = b; ngot = ngot + 1;
                                @(negedge scl); sda_s_o = 0;       // ACK
                                @(posedge scl); @(negedge scl); sda_s_o = 1;
                            end
                        end
                    end else begin
                        got[ngot] = b; ngot = ngot + 1;
                        nack_m = 0;
                        while (!nack_m) begin
                            b = rdtab[rdi & 3]; rdi = rdi + 1;
                            for (i = 7; i >= 0; i = i - 1) begin
                                sda_s_o = b[i];
                                @(posedge scl); @(negedge scl);
                            end
                            sda_s_o = 1;
                            @(posedge scl); nack_m = sda; @(negedge scl);
                        end
                    end
                end
            end
        end
    end

    // ---------------- skenario ----------------
    integer errs = 0;
    task check(input [255:0] name, input [31:0] got_v, input [31:0] exp_v);
    begin
        if (got_v !== exp_v) begin
            errs = errs + 1;
            $display("FAIL %0s: got %h exp %h", name, got_v, exp_v);
        end else $display("ok   %0s = %h", name, got_v);
    end
    endtask

    initial begin
        #100 RST = 1; #100;
        nstart = 0; nstop = 0;                   // buang tepi palsu saat inisialisasi bus
        axi_read(3); check("DIV default", rd, 31);

        // 1. tulis 3 byte: alamat 0x78, 0x00, 0xAE lalu STOP
        op(5'b00101, 8'h78); axi_read(2); check("addr ack (nack=0)", rd[1], 0);
        op(5'b00100, 8'h00);
        op(5'b00110, 8'hAE);
        check("ngot", ngot, 3);
        check("got0", got[0], 8'h78); check("got1", got[1], 8'h00); check("got2", got[2], 8'hAE);
        check("nstop", nstop, 1);

        // 2. alamat salah -> NACK, lalu STOP
        op(5'b00101, 8'h50); axi_read(2); check("addr salah nack=1", rd[1], 1);
        op(5'b00010, 8'h00);
        check("nstop", nstop, 2);

        // 3. baca 2 byte: ACK lalu NACK+STOP
        op(5'b00101, 8'h79);
        op(5'b01000, 8'h00); axi_read(0); check("read0", rd[7:0], 8'hA5);
        op(5'b11010, 8'h00); axi_read(0); check("read1", rd[7:0], 8'h5A);
        check("nstop", nstop, 3);

        // 4. repeated START: tulis pointer lalu baca
        ngot = 0;
        op(5'b00101, 8'h78);
        op(5'b00100, 8'h10);
        op(5'b00101, 8'h79);                       // repeated START + alamat baca
        op(5'b11010, 8'h00); axi_read(0); check("rstart read", rd[7:0], 8'hC3);
        check("nstart", nstart, 5);
        check("nstop", nstop, 4);
        check("got ptr", got[1], 8'h10);

        // 5. DIV < 4 ditolak
        axi_write(3, 2); axi_read(3); check("DIV tolak", rd, 31);
        axi_write(3, 10); axi_read(3); check("DIV 10", rd, 10);

        // 6. arbitrasi: master kirim 0xFF, bus ditahan low oleh pihak lain
        axi_write(3, 31);
        force sda = 1'b0;
        op(5'b00101, 8'hFF);
        release sda;
        axi_read(2); check("arb_lost", rd[2], 1);
        axi_read(2); check("idle setelah arb", rd[0], 0);

        if (errs == 0) $display("PASS"); else $display("FAIL: %0d error", errs);
        $finish;
    end
    initial begin #20_000_000 $display("TIMEOUT"); $finish; end
endmodule
