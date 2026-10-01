# Ringkasan Benchmark Sintesis — Bab IV

Metodologi: 5x `make synth` berturut-turut per konfigurasi, RTL tidak diubah sama sekali di antara run
(`make clean` dijalankan sebelum tiap run supaya Yosys/nextpnr benar-benar dijalankan ulang, bukan di-skip
oleh dependency-cache Make). Fmax yang dicatat adalah angka **post-route** (setelah tahap `router1`
verifikasi rute legal), bukan estimasi pra-routing dari placer.

- **old_4kb_1.5mhz**: RTL pada commit `548f33b` (RAM 4 KB / 1024 words, clock `clk100/64` = 1.5625 MHz),
  diambil lewat `git worktree`, tanpa mengubah working tree utama.
- **new_32kb_50mhz**: RTL saat ini (commit `c5a983f`, RAM 32 KB / 8192 words, clock `clk100/2` = 50 MHz).

## Statistik Fmax (MHz)

| Config | n | Mean | Std Dev | Min | Max |
|---|---|---|---|---|---|
| old_4kb_1.5mhz | 5 | 66.16 | 0.00 | 66.16 | 66.16 |
| new_32kb_50mhz | 5 | 67.57 | 0.00 | 67.57 | 67.57 |

**Temuan penting**: standar deviasi = 0 pada kedua konfigurasi — seluruh 5 run per konfigurasi
menghasilkan Fmax yang **identik bit-demi-bit**. Ini berarti P&R (`nextpnr-xilinx`) pada toolchain ini
**deterministik** untuk RTL dan constraint yang sama (bukan proses stokastik dengan variasi run-to-run),
setidaknya dengan konfigurasi/seed default yang dipakai `make synth` di proyek ini. Variasi Fmax yang
sempat teramati di log-log sebelumnya (mis. 59.27 MHz, 61.49 MHz, 67.57 MHz pada sesi kerja yang sama)
ternyata disebabkan oleh **perubahan RTL yang nyata di antara run-run tersebut** (progres pengembangan:
ekspansi RAM, relokasi peta alamat, dst), bukan oleh non-determinisme algoritma P&R.

## Utilisasi Resource (identik across 5 run per config, sebagaimana diharapkan karena RTL sama)

| Config | LUT total | FF total | RAMB36E1 | DSP48 | CARRY4 |
|---|---|---|---|---|---|
| old_4kb_1.5mhz | 2163 | 1395 | 1 | 0 | 225 |
| new_32kb_50mhz | 2181 | 1403 | 8 | 0 | 223 |

Catatan:
- RAMB36E1 naik dari **1 → 8** block RAM (konsisten dengan ekspansi SRAM 4 KB → 32 KB; 8x lipat kapasitas
  RAM ≈ 8x lipat BRAM primitif yang dipakai, wajar karena tiap RAMB36E1 = 36 Kb ≈ 4.5 KB, dan ekspansi
  RAM murni menaikkan pemakaian BRAM, bukan LUT/FF logic).
- LUT/FF/CARRY4 relatif hampir sama antar config (selisih <1%) — masuk akal karena perubahan RTL utama
  (lebar bus alamat 10→13 bit, relokasi peta alamat AXI) hanya menyentuh sedikit logic combinational,
  bukan menambah blok fungsional besar.
- **DSP48 = 0 di kedua config** — mengonfirmasi ulang temuan `CLAUDE.md`: `MULT.v` (Booth multiplier)
  tidak pernah disintesis jadi hardware nyata karena tidak pernah dipanggil dari `FSM.v`.

## File pendukung

- `benchmark_results.csv` — 10 baris data mentah (5 run x 2 config).
- `synth_new_run1.txt` .. `synth_new_run5.txt` — log sintesis lengkap, state RAM 32KB/50MHz.
- `synth_old_run1.txt` .. `synth_old_run5.txt` — log sintesis lengkap, state RAM 4KB/1.5625MHz (commit `548f33b`).
