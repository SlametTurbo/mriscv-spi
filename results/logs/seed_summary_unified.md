# Sweep seed — top tunggal + GPIO bank 2 (2026-10-01)

RTL: basys3_top.v tunggal (switch/LED/7-seg/UART + encoder + OLED), `impl_axi` 8 slave
(GPIO bank 2 di word 0x4030). Yosys sekali, `nextpnr-xilinx --freq 50 --seed N`, Fmax post-route domain `clk`.

| Seed | Fmax | Seed | Fmax |
|---|---|---|---|
| 1 | 57.57 | 11 | 59.64 |
| 2 | 56.26 | 12 | 61.36 |
| 3 | 63.79 | 13 | **66.28** |
| 4 | 63.83 | 14 | 61.35 |
| 5 | 66.24 | 15 | 59.13 |
| 6 | 55.74 | 16 | 57.64 |
| 7 | 59.74 | 17 | 60.55 |
| 8 | 57.12 | 18 | 62.83 |
| 9 | 60.80 | 19 | 57.86 |
| 10 | 58.93 | 20 | 56.62 |

n=20, mean 60.16, std 3.16, min 55.74, max 66.28; semua PASS di 50 MHz. Seed 13 dikunci di Makefile.
Bitstream: bitstreams/basys_50mhz_unified_seed13.bit, log: bitstreams/synth_log_unified_seed13.txt.
