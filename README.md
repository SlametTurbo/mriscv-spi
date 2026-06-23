# mriscv-spi

Porting **mriscv** RISC-V soft-core (RV32I) ke FPGA **Digilent Basys3 (Artix-7)** menggunakan **open-source toolchain sepenuhnya tanpa Vivado** (yosys + nextpnr-xilinx + prjxray), dilengkapi **SPI runtime loader** untuk meng-*upload* program ke core tanpa rebuild bitstream.

Proyek ini dikembangkan sebagai bagian dari skripsi: membuktikan bahwa soft-core RISC-V bisa disintesis, di-*place & route*, dan dijalankan di FPGA Xilinx menggunakan flow open-source, sekaligus menambahkan peripheral (LED, seven-segment, Pmod, switch input) di atasnya.

> Core RISC-V berasal dari [onchipuis/mriscv](https://github.com/onchipuis/mriscv) (RV32I) dan telah dimodifikasi untuk kebutuhan integrasi di repo ini. Lihat bagian [Atribusi](#atribusi).

---

## Fitur

- **RV32I soft-core** berjalan di Basys3 lewat flow open-source (no Vivado).
- **SPI runtime loader** — program di-*upload* ke memori core via SPI master (Cheetah adapter), jadi ganti program **tidak perlu** rebuild bitstream.
- **Power-On Reset (POR) otomatis** — bitstream langsung jalan setelah konfigurasi tanpa harus menekan `btnC` manual.
- **Peripheral terintegrasi** lewat `basys3_top.v`:
  - `gpio_datanw[7:0]` → 8 LED onboard
  - Two-digit hex **seven-segment display** (decode + scan di hardware)
  - 8 pin **Pmod JB**
  - **Switch input** (`sw[7:0]`) → GPIO read path *(in progress)*

---

## Kebutuhan

### Hardware
- Digilent **Basys3** (Xilinx Artix-7 `xc7a35t`)
- **Cheetah SPI Host Adapter** (untuk upload program via SPI)
- Kabel USB (programming) + wiring SPI ke header Pmod

### Toolchain (open-source, tanpa Vivado)
| Tool | Fungsi |
|------|--------|
| [yosys](https://github.com/YosysHQ/yosys) | Sintesis Verilog → netlist |
| [nextpnr-xilinx](https://github.com/gatecat/nextpnr-xilinx) | Place & route untuk Xilinx |
| [prjxray](https://github.com/f4pga/prjxray) | Database bitstream Artix-7 (FASM → bit) |
| [openFPGALoader](https://github.com/trabucayre/openFPGALoader) | Upload bitstream ke board |
| RISC-V GCC toolchain | Compile firmware (`riscv32-unknown-elf-*` / `riscv64-...-elf-*`) |
| Python 3 + `cheetah.so` | Driver SPI master host-side |

---

## Struktur Direktori

```
mriscv-spi/
├── basys3_top.v          # Top-level: wiring core + peripheral (LED/7seg/Pmod/switch)
├── basys3_spi.xdc        # Constraint pin Basys3 (clock, LED, 7seg, switch, SPI)
├── SP32B1024.v           # Memori (block RAM model)
├── Makefile              # Build flow bitstream (synth → pnr → fasm → bit)
├── fw.mk                 # Build rules firmware (C/asm → .elf → .bin)
├── crt0.S                # Startup code (C runtime init)
├── link_c.ld             # Linker script
├── mriscv.h              # Header definisi register/peripheral untuk firmware
│
├── mriscv/               # RISC-V soft-core (RV32I) — dari onchipuis/mriscv, dimodifikasi
│
├── cheetah_mriscv.py     # Host script: upload program ke core via SPI
├── cheetah_loopback.py   # Test loopback SPI (debugging)
├── cheetah_py.py         # Library Cheetah adapter
├── cheetah.so            # Shared lib driver Cheetah
│
├── breathe.c             # Contoh firmware: LED breathing
├── ledshow.c             # Contoh firmware: pola LED
├── sevensegment.c        # Contoh firmware: seven-segment
├── switch_led.c          # Contoh firmware: switch → LED
└── main.c / main.cpp     # Template firmware
```

> **Catatan:** file hasil build (`spi.bit`, `spi.json`, `spi.frames`, `spi.fasm`, `build.log`, `*.elf`, `*.bin`) sengaja **tidak** di-*track* (lihat `.gitignore`). Semua bisa di-*regenerate* dari source.

---

## Cara Pakai

### 1. Build bitstream (sekali, atau saat menambah peripheral)

```bash
make            # menjalankan synth (yosys) → pnr (nextpnr) → fasm → spi.bit
```

Bitstream `spi.bit` ini berisi **core + peripheral**, belum berisi program aplikasi.

### 2. Upload bitstream ke board

```bash
openFPGALoader spi.bit
```

> ⚠️ **Penting:** Basys3 menyimpan bitstream di **SRAM volatile** (tergantung posisi jumper JTAG). Setelah board dimatikan / dicabut daya, bitstream **hilang**. Jalankan ulang `openFPGALoader spi.bit` setiap kali board dinyalakan, **sebelum** upload program.

### 3. Upload program via SPI (tanpa rebuild!)

Compile firmware lalu kirim via SPI master:

```bash
# Compile firmware (contoh: ledshow)
make -f fw.mk ledshow.bin

# Upload ke core via Cheetah SPI
python3 cheetah_mriscv.py ledshow.bin
```

Ganti program kapan saja dengan meng-upload `.bin` lain — **tidak perlu** `make` ulang bitstream. Inilah inti dari *SPI runtime loader*.

---

## Arsitektur

### Alur sistem

```
┌──────────────┐   SPI    ┌──────────────────────────────────────┐
│  Host PC     │ ───────► │            FPGA Basys3 (Artix-7)      │
│  (Cheetah)   │  loader  │  ┌────────────┐    ┌───────────────┐  │
│ cheetah_*.py │          │  │ SPI AXI    │───►│  mriscv core  │  │
└──────────────┘          │  │ master     │    │  (RV32I)      │  │
                          │  └────────────┘    └───────┬───────┘  │
                          │                            │ GPIO/bus │
                          │                    ┌───────▼────────┐ │
                          │                    │  Peripheral:   │ │
                          │                    │  LED / 7seg /  │ │
                          │                    │  Pmod / switch │ │
                          │                    └────────────────┘ │
                          └──────────────────────────────────────┘
```

1. **Bitstream** mengkonfigurasi FPGA dengan core + peripheral + SPI loader.
2. Host (Cheetah) mengirim program lewat **SPI** → ditulis ke memori instruksi core.
3. Setelah loader selesai, core mulai *fetch & execute* dari memori.
4. Program mengontrol peripheral via **GPIO** (`completogpio.v`).

### Pemisahan bitstream vs program

| Aksi | Perlu rebuild bitstream? | Perlu upload SPI? |
|------|:---:|:---:|
| Menambah/ubah peripheral (pin, display logic) | ✅ Ya | ✅ Ya |
| Ganti program aplikasi | ❌ Tidak | ✅ Ya |
| Power cycle board | — | re-upload `spi.bit` dulu |

---

## Troubleshooting

### Bitstream "hilang" setelah board dimatikan
**Gejala:** board tidak merespons setelah dicabut daya / restart.
**Sebab:** bitstream disimpan di SRAM volatile (bukan flash).
**Solusi:** jalankan `openFPGALoader spi.bit` lagi setiap kali board menyala, sebelum upload program.

### State non-deterministik setelah konfigurasi (kadang jalan, kadang tidak)
**Gejala:** behaviour berubah-ubah antar build, tanpa ubah source.
**Sebab:** register tanpa nilai inisialisasi di level deklarasi → state pasca-konfigurasi tidak terdefinisi di Artix-7. Variasi *placement* nextpnr membuatnya tak terprediksi build-to-build.
**Solusi:** beri nilai awal di deklarasi register (`reg foo = 0;` → ter-map ke atribut `INIT`), **dan** tambahkan POR counter di top-level untuk reset deterministik. Terapkan keduanya untuk robust.

### Harus tekan `btnC` manual agar bitstream jalan
**Sebab:** tidak ada Power-On Reset otomatis.
**Solusi:** POR counter di `basys3_top.v` men-generate pulse reset otomatis saat startup (sudah diterapkan di repo ini).

### Program tidak ter-upload / SPI tidak respons
Debug dengan **isolasi berlapis** — verifikasi tiap lapisan secara independen sebelum menyimpulkan:
1. **FPGA health** — blink test sederhana, pastikan board hidup & terkonfigurasi.
2. **Host health** — `cheetah_loopback.py` untuk memastikan adapter & driver jalan.
3. **SPI master activity** — cek aktivitas di sisi FPGA.
4. **Wiring** — periksa koneksi fisik SPI (MOSI/MISO/SCK/CS) ke header Pmod.

---

## Atribusi

- **RISC-V core:** [onchipuis/mriscv](https://github.com/onchipuis/mriscv) (RV32I). Lisensi asli core ada di `mriscv/LICENSE`. Core ini telah dimodifikasi (antara lain pada `mriscv_axi/impl_axi/impl_axi.v`, `mriscv_axi/spi_axi_master/spi_axi_master.v`, `mriscv_axi/util/bus_sync_sf.v`) untuk integrasi di proyek ini.
- **Toolchain:** YosysHQ (yosys), nextpnr-xilinx, prjxray (F4PGA), openFPGALoader — masing-masing dengan lisensinya sendiri.

---

## Status & Roadmap

- [x] Core RV32I jalan di Basys3 via flow open-source
- [x] SPI runtime loader
- [x] POR otomatis
- [x] Peripheral: LED, seven-segment, Pmod JB
- [ ] Switch input (`sw[7:0]` → LED via program SPI) — *end-to-end validation in progress*
- [ ] Opsi persistensi bitstream (flash) — *future work*
- [ ] Peripheral tambahan — *future work*

---

*Dikembangkan sebagai bagian dari skripsi. Pertanyaan/diskusi silakan lewat Issues.*
