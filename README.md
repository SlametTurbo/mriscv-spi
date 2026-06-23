# mriscv-spi

Porting the **mriscv** RISC-V soft-core (RV32I) to the **Digilent Basys3 (Artix-7)** FPGA using a **fully open-source toolchain — no Vivado** (yosys + nextpnr-xilinx + prjxray), with an **SPI runtime loader** for uploading programs to the core without rebuilding the bitstream.

This project was developed as part of an undergraduate thesis: demonstrating that a RISC-V soft-core can be synthesized, placed & routed, and run on a Xilinx FPGA using an open-source flow, while adding peripherals (LEDs, seven-segment, Pmod, switch input) on top of it.

> The RISC-V core originates from [onchipuis/mriscv](https://github.com/onchipuis/mriscv) (RV32I) and has been modified for integration in this repository. See [Attribution](#attribution).

---

## Features

- **RV32I soft-core** running on the Basys3 via an open-source flow (no Vivado).
- **SPI runtime loader** — programs are uploaded to the core's memory over SPI (Cheetah adapter), so switching programs requires **no** bitstream rebuild.
- **Automatic Power-On Reset (POR)** — the bitstream runs immediately after configuration, no need to press `btnC` manually.
- **Integrated peripherals** via `basys3_top.v`:
  - `gpio_datanw[7:0]` → 8 onboard LEDs
  - Two-digit hex **seven-segment display** (hardware decode + scan)
  - 8 **Pmod JB** pins
  - **Switch input** (`sw[7:0]`) → GPIO read path *(in progress)*

---

## Requirements

### Hardware
- Digilent **Basys3** (Xilinx Artix-7 `xc7a35t`)
- **Cheetah SPI Host Adapter** (for uploading programs over SPI)
- USB cable (programming) + SPI wiring to the Pmod header

### Toolchain (open-source, no Vivado)
| Tool | Purpose |
|------|---------|
| [yosys](https://github.com/YosysHQ/yosys) | Verilog synthesis → netlist |
| [nextpnr-xilinx](https://github.com/gatecat/nextpnr-xilinx) | Place & route for Xilinx |
| [prjxray](https://github.com/f4pga/prjxray) | Artix-7 bitstream database (FASM → bit) |
| [openFPGALoader](https://github.com/trabucayre/openFPGALoader) | Upload bitstream to the board |
| RISC-V GCC toolchain | Compile firmware (`riscv32-unknown-elf-*` / `riscv64-...-elf-*`) |
| Python 3 + `cheetah.so` | Host-side SPI master driver |

---

## Directory Structure

```
mriscv-spi/
├── basys3_top.v          # Top-level: core + peripheral wiring (LED/7seg/Pmod/switch)
├── basys3_spi.xdc        # Basys3 pin constraints (clock, LED, 7seg, switch, SPI)
├── SP32B1024.v           # Memory (block RAM model)
├── Makefile              # Bitstream build flow (synth → pnr → fasm → bit)
├── fw.mk                 # Firmware build rules (C/asm → .elf → .bin)
├── crt0.S                # Startup code (C runtime init)
├── link_c.ld             # Linker script
├── mriscv.h              # Register/peripheral definitions for firmware
│
├── mriscv/               # RISC-V soft-core (RV32I) — from onchipuis/mriscv, modified
│
├── cheetah_mriscv.py     # Host script: upload program to the core over SPI
├── cheetah_loopback.py   # SPI loopback test (debugging)
├── cheetah_py.py         # Cheetah adapter library
├── cheetah.so            # Cheetah driver shared library
│
├── breathe.c             # Example firmware: LED breathing
├── ledshow.c             # Example firmware: LED pattern
├── sevensegment.c        # Example firmware: seven-segment
├── switch_led.c          # Example firmware: switch → LED
└── main.c / main.cpp     # Firmware template
```

> **Note:** build outputs (`spi.bit`, `spi.json`, `spi.frames`, `spi.fasm`, `build.log`, `*.elf`, `*.bin`) are intentionally **not** tracked (see `.gitignore`). They can all be regenerated from source.

---

## Usage

### 1. Build the bitstream (once, or when adding peripherals)

```bash
make            # runs synth (yosys) → pnr (nextpnr) → fasm → spi.bit
```

This `spi.bit` contains the **core + peripherals**, but no application program yet.

### 2. Upload the bitstream to the board

```bash
openFPGALoader spi.bit
```

> ⚠️ **Important:** The Basys3 stores the bitstream in **volatile SRAM** (depending on the JTAG jumper position). After the board is powered off / unplugged, the bitstream is **lost**. Re-run `openFPGALoader spi.bit` every time the board powers on, **before** uploading a program.

### 3. Upload a program over SPI (no rebuild!)

Compile the firmware and send it via the SPI master:

```bash
# Compile firmware (e.g. ledshow)
make -f fw.mk ledshow.bin

# Upload to the core over Cheetah SPI
python3 cheetah_mriscv.py ledshow.bin
```

Swap programs anytime by uploading a different `.bin` — **no** need to re-`make` the bitstream. This is the essence of the *SPI runtime loader*.

---

## Architecture

### System flow

```
┌──────────────┐   SPI    ┌──────────────────────────────────────┐
│  Host PC     │ ───────► │            FPGA Basys3 (Artix-7)      │
│  (Cheetah)   │  loader  │  ┌────────────┐    ┌───────────────┐  │
│ cheetah_*.py │          │  │ SPI AXI    │───►│  mriscv core  │  │
└──────────────┘          │  │ master     │    │  (RV32I)      │  │
                          │  └────────────┘    └───────┬───────┘  │
                          │                            │ GPIO/bus │
                          │                    ┌───────▼────────┐ │
                          │                    │  Peripherals:  │ │
                          │                    │  LED / 7seg /  │ │
                          │                    │  Pmod / switch │ │
                          │                    └────────────────┘ │
                          └──────────────────────────────────────┘
```

1. The **bitstream** configures the FPGA with the core + peripherals + SPI loader.
2. The host (Cheetah) sends a program over **SPI** → written into the core's instruction memory.
3. Once the loader finishes, the core begins fetching & executing from memory.
4. The program drives peripherals via **GPIO** (`completogpio.v`).

### Bitstream vs. program separation

| Action | Bitstream rebuild? | SPI upload? |
|--------|:---:|:---:|
| Add/change peripheral (pins, display logic) | ✅ Yes | ✅ Yes |
| Swap application program | ❌ No | ✅ Yes |
| Power cycle the board | — | re-upload `spi.bit` first |

---

## Troubleshooting

### Bitstream "lost" after the board is powered off
**Symptom:** the board stops responding after being unplugged / restarted.
**Cause:** the bitstream is stored in volatile SRAM (not flash).
**Fix:** re-run `openFPGALoader spi.bit` each time the board powers on, before uploading a program.

### Non-deterministic state after configuration (sometimes works, sometimes not)
**Symptom:** behaviour changes between builds without any source change.
**Cause:** registers without declaration-level initial values → undefined post-configuration state on Artix-7. nextpnr placement variation makes this unpredictable build-to-build.
**Fix:** give registers initial values at declaration (`reg foo = 0;` → maps to the `INIT` attribute), **and** add a POR counter in the top-level for a deterministic reset. Apply both for robustness.

### Must press `btnC` manually for the bitstream to run
**Cause:** no automatic Power-On Reset.
**Fix:** a POR counter in `basys3_top.v` generates an automatic reset pulse at startup (already applied in this repo).

### Program won't upload / SPI not responding
Debug with **layered isolation** — verify each layer independently before drawing conclusions:
1. **FPGA health** — simple blink test, confirm the board is alive & configured.
2. **Host health** — `cheetah_loopback.py` to confirm the adapter & driver work.
3. **SPI master activity** — check activity on the FPGA side.
4. **Wiring** — inspect the physical SPI connections (MOSI/MISO/SCK/CS) to the Pmod header.

---

## Attribution

- **RISC-V core:** [onchipuis/mriscv](https://github.com/onchipuis/mriscv) (RV32I). The core's original license is in `mriscv/LICENSE`. The core has been modified (among others in `mriscv_axi/impl_axi/impl_axi.v`, `mriscv_axi/spi_axi_master/spi_axi_master.v`, `mriscv_axi/util/bus_sync_sf.v`) for integration in this project.
- **Toolchain:** YosysHQ (yosys), nextpnr-xilinx, prjxray (F4PGA), openFPGALoader — each under its own license.

---

## Status & Roadmap

- [x] RV32I core running on Basys3 via the open-source flow
- [x] SPI runtime loader
- [x] Automatic POR
- [x] Peripherals: LED, seven-segment, Pmod JB
- [ ] Switch input (`sw[7:0]` → LED via SPI-uploaded program) — *end-to-end validation in progress*
- [ ] Bitstream persistence option (flash) — *future work*
- [ ] Additional peripherals — *future work*

---

*Developed as part of an undergraduate thesis. Questions/discussion welcome via Issues.*
