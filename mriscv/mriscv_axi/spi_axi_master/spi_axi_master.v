// ============================================================================
// spi_axi_master.v  -- DITULIS ULANG: single-clock (domain CLK), FPGA-routable.
// SCLK/CEB/DATA di-oversample di domain CLK (bukan dipakai sbg clock) -> tak ada
// clock kedua utk dirutekan, tak perlu bus_sync_sf, tak perlu BUFG utk SCLK.
// Port identik dgn versi asli (impl_axi tak berubah). Mode: tulis RAM + lepas core.
//   Syarat: CLK >= ~4x SCLK (oversampling). Dgn CLK ~1.5MHz, SCLK <= ~200 kHz.
//   SPI standar: CS(CEB) rendah, clock 66 bit (mode 0, MSB-first), CS tinggi.
//   Frame: {instr[1:0], addr[31:0], data[31:0]}  10=write, 00=nop(lepas core).
// ============================================================================
module spi_axi_master #(
    parameter sword = 32, parameter impl = 0, parameter syncing = 0
)(
    input              CEB, input SCLK, input DATA, output DOUT,
    input              RST, output PICORV_RST,
    input              CLK,
    output reg axi_awvalid = 0, input axi_awready,
    output [sword-1:0] axi_awaddr, output [2:0] axi_awprot,
    output reg axi_wvalid = 0, input axi_wready,
    output [sword-1:0] axi_wdata, output [3:0] axi_wstrb,
    input axi_bvalid, output reg axi_bready = 0,
    output reg axi_arvalid = 0, input axi_arready,
    output [sword-1:0] axi_araddr, output [2:0] axi_arprot,
    input axi_rvalid, output reg axi_rready = 0, input [sword-1:0] axi_rdata
);
    localparam NBITS = 2 + sword + sword;   // 66

    // ---- sinkronkan input SPI ke domain CLK (2-3 FF) ----
    reg [2:0] sclk_s = 0, ceb_s = 3'b111, data_s = 0;
    always @(posedge CLK) begin
        if (RST==1'b0) begin sclk_s<=0; ceb_s<=3'b111; data_s<=0; end
        else begin
            sclk_s <= {sclk_s[1:0], SCLK};
            ceb_s  <= {ceb_s[1:0],  CEB};
            data_s <= {data_s[1:0], DATA};
        end
    end
    wire sclk_rise  = (sclk_s[2:1] == 2'b01);   // tepi naik SCLK terdeteksi di CLK
    wire cs_active  = ~ceb_s[2];                 // CS rendah = aktif
    wire mosi       = data_s[2];

    // ---- shift register + penghitung bit ----
    reg [NBITS-1:0] sft = 0;
    reg [7:0]       bitcnt = 0;
    reg             picorv_rst_r = 0;
    assign PICORV_RST = picorv_rst_r;

    wire [NBITS-1:0] full        = {sft[NBITS-2:0], mosi};  // frame penuh saat bit terakhir
    wire [1:0]       full_instr  = full[NBITS-1 -: 2];
    wire [sword-1:0] full_addr   = full[NBITS-3 -: sword];
    wire [sword-1:0] full_data   = full[sword-1:0];

    reg              do_write = 0;
    reg [sword-1:0]  waddr = 0, wdata_r = 0;

    always @(posedge CLK) begin
        if (RST==1'b0) begin
            sft<=0; bitcnt<=0; picorv_rst_r<=0; do_write<=0;
        end else begin
            do_write <= 1'b0;
            if (!cs_active) begin
                bitcnt <= 0;                       // CS tinggi -> reset frame
            end else if (sclk_rise) begin
                sft <= {sft[NBITS-2:0], mosi};
                if (bitcnt == NBITS-1) begin
                    bitcnt <= 0;
                    if (full_instr == 2'b10) begin            // WRITE
                        waddr <= full_addr; wdata_r <= full_data; do_write <= 1'b1;
                    end else if (full_instr == 2'b00) begin   // NOP -> set PICORV_RST
                        picorv_rst_r <= full_data[0];
                    end
                end else bitcnt <= bitcnt + 1'b1;
            end
        end
    end

    // ---- FSM tulis AXI4-lite (domain CLK) ----
    assign axi_awaddr = waddr; assign axi_araddr = waddr;
    assign axi_wdata  = wdata_r; assign axi_wstrb = 4'b1111;
    assign axi_awprot = 3'b000; assign axi_arprot = 3'b000;

    localparam S_IDLE=0, S_AW=1, S_B=2;
    reg [1:0] st = S_IDLE;
    always @(posedge CLK) begin
        if (RST==1'b0) begin
            st<=S_IDLE; axi_awvalid<=0; axi_wvalid<=0; axi_bready<=0;
            axi_arvalid<=0; axi_rready<=0;
        end else case (st)
            S_IDLE: if (do_write) begin axi_awvalid<=1; axi_wvalid<=1; st<=S_AW; end
            S_AW: begin
                if (axi_awready) axi_awvalid<=0;
                if (axi_wready)  axi_wvalid<=0;
                if ((axi_awready|~axi_awvalid) & (axi_wready|~axi_wvalid)) begin
                    axi_bready<=1; st<=S_B;
                end
            end
            S_B: if (axi_bvalid) begin axi_bready<=0; st<=S_IDLE; end
        endcase
    end

    assign DOUT = 1'b0;   // write-only loader (MISO tak dipakai)
endmodule
