# Sweep seed nextpnr-xilinx — RTL terkini (2026-10-01)

RTL: RAM 32 KB, 50 MHz, + UART TX/RX, LED trap, BUS_RST, sinkronizer reset. Yosys dijalankan sekali
(`basys.json`), 20 run `nextpnr-xilinx --freq 50 --seed N`. Fmax = angka post-route domain `clk`.

| Seed | Fmax (MHz) | Seed | Fmax (MHz) |
|---|---|---|---|
| 1 | 61.17 | 11 | **68.06** |
| 2 | 64.20 | 12 | 59.33 |
| 3 | 64.30 | 13 | 63.94 |
| 4 | 60.27 | 14 | 63.74 |
| 5 | 63.66 | 15 | 65.66 |
| 6 | 61.98 | 16 | 58.81 |
| 7 | 58.51 | 17 | 63.02 |
| 8 | 63.85 | 18 | 64.97 |
| 9 | 59.90 | 19 | 64.89 |
| 10 | 61.63 | 20 | 66.23 |

n=20, mean 62.91, std 2.62, min 58.51 (seed 7), max 68.06 (seed 11). Semua PASS di 50 MHz.
Seed 11 dikunci di Makefile (`PNR_SEED`). Bitstream: `bitstreams/basys_50mhz_seed11.bit`,
log: `bitstreams/synth_log_seed11.txt`. Catatan: Fmax bukan sign-off timing penuh (lihat CLAUDE.md).
Log per seed + skrip: `seedsweep/`.
