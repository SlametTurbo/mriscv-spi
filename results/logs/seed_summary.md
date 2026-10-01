# Sensitivitas `nextpnr-xilinx` terhadap `--seed` — Bab IV

Metodologi: RTL **tidak diubah** dari state `new_32kb_50mhz` (RAM 32 KB, clock 50 MHz — sama persis
dengan benchmark sebelumnya). Sintesis Yosys (`spi.json`) dijalankan **satu kali saja** dan dipakai ulang
untuk seluruh 10 run `nextpnr-xilinx`, supaya perbedaan hasil murni berasal dari algoritma
placement-and-routing (`--seed`), bukan dari variasi netlist. Fmax yang dicatat adalah angka
**post-route** (nilai kedua/final di tiap log, setelah tahap `router1` verifikasi rute legal).

## Hasil per seed

| Seed | Fmax (MHz) |
|---|---|
| 1 | 69.88 |
| 2 | 68.74 |
| 3 | 70.12 |
| 4 | 69.95 |
| 5 | 63.59 |
| 6 | 73.31 |
| 7 | 69.48 |
| 8 | 68.97 |
| 9 | 66.37 |
| 10 | 67.01 |

## Statistik

| | Fmax (MHz) |
|---|---|
| n | 10 |
| Mean | 68.74 |
| Std Dev | 2.61 |
| Min | 63.59 (seed 5) |
| Max | 73.31 (seed 6) |
| Rentang (max-min) | 9.72 (≈14.1% dari mean) |

## Perbandingan dengan benchmark seed-default (kemarin)

`benchmark_results.csv`, baris `new_32kb_50mhz` (5x `make synth`, **tanpa** `--seed` eksplisit —
nextpnr-xilinx memakai seed default internalnya): **67.57 MHz, std dev = 0** (lima run identik bit-demi-bit).

Ini **tidak kontradiktif** dengan hasil sweep di atas — ini melengkapi gambarannya:

- **Tanpa `--seed`**, nextpnr-xilinx memakai seed default yang **tetap/fixed** (bukan diacak). Karena
  itu, `make synth` berulang dengan RTL sama selalu mereproduksi hasil P&R yang identik persis — ini
  yang menjelaskan std dev=0 di benchmark kemarin.
- **Dengan `--seed` eksplisit berbeda-beda**, algoritma placer/router (`simulated annealing placer`)
  memang stokastik dan sensitif terhadap seed — terbukti dari rentang 63.59–73.31 MHz (spread ~14%)
  di atas.
- Nilai seed-default (67.57 MHz) jatuh **di dalam rentang** hasil sweep 10-seed (63.59–73.31 MHz),
  persisnya dekat median — bukan titik ekstrem, artinya seed default bukan kasus "kebetulan terbaik/
  terburuk", melainkan representasi yang cukup tipikal.

## Implikasi untuk margin timing (relevan ke catatan "margin tipis" di `CLAUDE.md`)

Clock core beroperasi di **50 MHz**. Bahkan pada **seed terburuk dari 10 sampel (seed 5, 63.59 MHz)**,
Fmax masih **~1.27x** di atas 50 MHz — margin tetap positif dan cukup sehat di seluruh 10 seed yang diuji
(margin berkisar 1.27x–1.47x). Tidak ada seed dalam sampel ini yang menyebabkan Fmax turun di bawah
titik operasi 50 MHz. Catatan: ini bukan jaminan formal (10 seed adalah sampel, bukan populasi lengkap
ruang seed), tapi memberi bukti empiris tambahan bahwa desain saat ini punya bantalan margin yang
masuk akal terhadap variasi P&R, bukan hanya "kebetulan" dari satu hasil seed-default saja.

## File pendukung

- `seed_results.csv` — 10 baris data mentah (seed, fmax_mhz).
- `synth_seed1.txt` .. `synth_seed10.txt` — log `nextpnr-xilinx` lengkap per seed.
- `spi.json` — netlist Yosys tunggal yang dipakai ulang di semua 10 run (memastikan variabel yang
  berubah murni `--seed`, bukan netlist).
