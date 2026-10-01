# Kenaikan Clock Core — Ringkasan Perubahan

Tanggal: 2026-08-28

## Perubahan

**File**: `basys3_top.v`

```diff
-    // Clock /64: 100 MHz -> ~1.5625 MHz
-    reg [5:0] divcnt = 0;
-    always @(posedge clk100) divcnt <= divcnt + 1'b1;
-    wire clk = divcnt[5];
+    // Clock /2: 100 MHz -> 50 MHz
+    reg divcnt = 0;
+    always @(posedge clk100) divcnt <= ~divcnt;
+    wire clk = divcnt;
```

Clock core dinaikkan dari **1.5625 MHz** (÷64) menjadi **50 MHz** (÷2) — kenaikan 32x.
Divider disederhanakan jadi satu bit toggle-FF karena ÷2 tidak butuh counter multi-bit.

## Konteks keputusan

Fmax hasil P&R sebelumnya: **66.16 MHz**. Pilihan yang dipertimbangkan:

| Opsi | Frekuensi | Margin ke Fmax |
|---|---|---|
| `divcnt[2]` | 12.5 MHz | ~5.3x (paling konservatif) |
| `divcnt[1]` | 25 MHz | ~2.6x |
| `divcnt[0]` | **50 MHz (dipilih)** | **~1.3x (paling agresif)** |

Margin 1.3x tergolong tipis — ada risiko timing closure gagal saat P&R meskipun constraint 12 MHz sebelumnya lolos dengan longgar. Belum diverifikasi ulang dengan `make synth` karena environment ini tidak punya toolchain sintesis.

## Yang TIDAK berubah (dan kenapa aman)

- **SCLK SPI loader** tetap 100 kHz. Aturan proyek: SCLK ≤ ~1/4 clock core — batas ini jadi *lebih longgar* seiring clock core naik (sekarang 1/4 dari 50 MHz = 12.5 MHz), jadi tidak perlu penyesuaian.
- **`basys3_spi.xdc`**: hanya `clk100` (100 MHz, port fisik) yang punya `create_clock`. Tidak ada generated-clock constraint untuk `clk` internal di file ini sebelum maupun sesudah perubahan, jadi tidak ada yang perlu ditambahkan di XDC untuk perubahan ini.
- Modul lain (`impl_axi`, GPIO sync, scan seven-segment) mereferensikan `clk`/`clk100` seperti biasa — tidak ada perubahan interface.

## Belum diverifikasi (perlu dilakukan manual)

1. **Elaborate check**: `iverilog -g2012 -t null -s basys3_top` atas `basys3_top.v SP32B1024.v` + seluruh `mriscv/mriscv_axi/**` dan `mriscv/mriscvcore/**` (kecuali `_tb.v`) — tidak bisa dijalankan di environment ini (iverilog tidak terpasang, tidak ada sudo password-less).
2. **`make synth XDC=basys3_spi.xdc`** — cek laporan timing/Fmax. Kalau P&R gagal closure di 50 MHz, turunkan ke `divcnt[1]` (25 MHz).
3. **Uji SPI upload** (`make prog`) masih reliable di board fisik pada clock baru.
4. **Kalibrasi ulang delay firmware** — semua busy-wait (`delay()`, `ihold()`) di `main.c`, `ledshow.c`, `sevensegment.c`, dan file-file di `oled-with-encoder/` dikalibrasi untuk 1.5625 MHz. Pada 50 MHz (32x lebih cepat), delay yang sama akan menghasilkan durasi wall-clock 32x lebih pendek — perlu dikalikan ulang konstantanya kalau timing yang terasa di board penting (mis. animasi LED, I2C bit-bang OLED).

## Catatan untuk task berikutnya

Task #2 (sambungkan `trap` ke LED) dan task #3 (4 digit seven-segment) di `CLAUDE.md` belum dikerjakan pada perubahan ini — hanya task #1 (naikkan clock) yang disentuh.
