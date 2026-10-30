# Sweep seed — peta alamat baru (2026-10-30)

RTL: top tunggal, `impl_axi` 8 slave, peta alamat `n << 16` (byte) dengan mask jendela penuh
`0x3FFF` word (SRAM `0x1FFF`). Netlist Yosys sama untuk semua run (`basys.json` dari
`make synth`), lalu `nextpnr-xilinx --freq 50 --seed N`. Fmax = post-route domain `clk`.
Skrip: `results/seedsweep/addrmap/run.sh`, log per seed: `results/seedsweep/addrmap/sN.log`.

| Seed | Fmax | Seed | Fmax |
|---|---|---|---|
| 1 | 57.29 | 11 | 50.39 |
| 2 | 59.76 | 12 | 64.35 |
| 3 | 61.30 | 13 | 54.79 |
| 4 | 59.67 | 14 | 62.90 |
| 5 | 62.84 | 15 | 63.55 |
| 6 | 61.94 | 16 | 65.43 |
| 7 | 56.20 | 17 | **67.15** |
| 8 | 63.27 | 18 | 61.93 |
| 9 | 66.10 | 19 | 59.61 |
| 10 | 63.52 | 20 | 60.86 |

n=20, mean 61.14, std 4.07, median 61.94, min 50.39 (seed 11), max 67.15 (seed 17);
semua PASS di 50 MHz. Utilisasi sama untuk semua seed: 4405 LUT (6%), 1657 FF (2%), 8 RAMB36 (10%).

Seed 13 (seed terkunci sebelumnya, dipilih untuk RTL lama) = 54.79 MHz, sama persis dengan
`make synth` → konfirmasi sweep setara alur Makefile. Seed 17 dikunci di Makefile (`PNR_SEED ?= 17`).
Jalur kritis seed 17: 14.9 ns, mulai `axi4_interconnect.counter_wrequests`.

Bitstream seed 17 dibuat dari `s17.fasm` (fasm2frames + xc7frames2bit, sama dengan openXC7.mk):
`bitstreams/basys_50mhz_addrmap_seed17.bit`. Validasi jalur manual: bitstream seed 13 yang dibuat
dengan cara sama identik (mulai sync word) dengan hasil `make synth`.

Pembanding sweep sebelumnya (`seed_summary_unified.md`, RTL 2026-10-01 tanpa I2C/UART gabungan):
mean 60.16, min 55.74, max 66.28.
