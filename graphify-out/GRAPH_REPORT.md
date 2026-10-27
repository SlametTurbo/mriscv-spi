# Graph Report - mriscv-spi  (2026-10-09)

## Corpus Check
- Large corpus: 182 files · ~5,163,093 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 637 nodes · 969 edges · 74 communities (26 shown, 48 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 171 edges (avg confidence: 0.86)
- Token cost: 376,504 input · 0 output

## Community Hubs (Navigation)
- Firmware Apps & HAL
- OLED Encoder Firmware
- Project Docs & Clock Upgrade
- Core Module Docs (ES)
- CIDIC Test Board PCB
- SRAM AXI Testbench
- Hex/Upload Python Scripts
- mRISC-V 100MHz Paper
- I2C Master Hardware
- Upstream SoC Diagram
- Basys3 Top & GPIO Bank TB
- LED Show Firmware
- Cheetah SPI Python API
- APB GPIO Composition
- Encoder OLED Bit-bang
- ALU Operations
- Core Block Diagram
- OLED Test Bit-bang
- APB Variant SoC
- UART TX & Testbench
- impl_axi SoC & UART RX TB
- Cheetah Extension Info
- AXI Interconnect Testbench
- Cheetah Device Discovery
- Cheetah SPI Batch Transfer
- APB ADC Interface
- APB DAC Interface
- APB SoC Testbench
- AXI ADC Interface
- AXI DAC Interface
- Bus Reset Testbench
- impl_axi Testbench
- APB AXI4 Interconnect
- AXI4 Interconnect
- Priority Encoder Util
- Toolchain Installer
- Seed Sweep Script
- Seed Sweep Script 2
- APB GPIO Decoder
- APB GPIO RS Flip-flop
- APB GPIO Data Flops
- APB GPIO Address Latch
- APB GPIO Handshake FSM
- AXI GPIO Decoder
- AXI GPIO RS Flip-flop
- AXI GPIO Data Flops
- AXI GPIO Address Latch
- AXI GPIO Handshake FSM
- Bus Sync Util
- Core Cycle/Instr Counters
- Disassembly Script
- Cheetah Close
- Cheetah Device Address
- Cheetah Host Speed
- Cheetah Open
- Cheetah Port
- Cheetah Sleep
- Cheetah Async Submit
- Cheetah Batch Length
- Cheetah SPI Bitrate
- Cheetah SPI Configure
- Cheetah Queue Array
- Cheetah Queue Byte
- Cheetah Queue Clear
- Cheetah Queue Delay
- Cheetah Queue OE
- Cheetah Queue SS
- Cheetah Status String
- Cheetah Target Power
- Cheetah Unique ID

## God Nodes (most connected - your core abstractions)
1. `led_set()` - 26 edges
2. `impl_axi` - 16 edges
3. `main()` - 14 edges
4. `main()` - 13 edges
5. `uart_puts()` - 13 edges
6. `ssd1306_fillRect()` - 13 edges
7. `ALU` - 12 edges
8. `ssd1306_clearDisplay()` - 11 edges
9. `ssd1306_print()` - 11 edges
10. `i2c_master_tb` - 11 edges

## Surprising Connections (you probably didn't know these)
- `SPI SCLK <= 1/4 core clock rule` --conceptually_related_to--> `SPI Runtime Loader`  [INFERRED]
  docs/CLOCK_UPGRADE.md → README.md
- `Timing margin over 50 MHz operating point` --conceptually_related_to--> `Core clock 50 MHz via divcnt toggle-FF`  [INFERRED]
  results/logs/seed_summary.md → docs/CLOCK_UPGRADE.md
- `spi_axi_master (programming SPI master)` --implements--> `SPI Runtime Loader`  [INFERRED]
  rtl/mriscv/README.md → README.md
- `Core clock 50 MHz via divcnt toggle-FF` --references--> `basys3_top.v single top-level`  [INFERRED]
  docs/CLOCK_UPGRADE.md → README.md
- `onchipuis/mriscv upstream RV32I core` --conceptually_related_to--> `mriscv microcontroller (RV32I core, 4KB SRAM, ADC, DAC, GPIO, SPI master/slave)`  [INFERRED]
  README.md → rtl/mriscv/README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Seed sweep / Fmax measurement methodology** — results_logs_benchmark_summary_pnr_deterministic_default_seed, results_logs_seed_summary_seed_sensitivity, results_logs_benchmark_summary_post_route_fmax, results_logs_seed_summary_rtl_terkini_pnr_seed_11_lock, results_logs_seed_summary_unified_pnr_seed_13_lock, results_logs_seed_summary_rtl_terkini_pnr_freq_50 [INFERRED 0.85]
- **mriscv AXI SoC components** — rtl_mriscv_readme_impl_axi, rtl_mriscv_readme_axi4_interconnect, rtl_mriscv_readme_spi_axi_master, rtl_mriscv_readme_spi_axi_slave, rtl_mriscv_readme_axi_sp32b1024, rtl_mriscv_mriscvcore_readme_mriscvcore [EXTRACTED 1.00]
- **SPI program upload flow** — readme_cheetah_spi_adapter, readme_spi_runtime_loader, rtl_mriscv_readme_spi_axi_master, readme_bitstream_program_separation [INFERRED 0.85]
- **mRISC-V SoC blocks on AXI4-Lite/APB** — rtl_mriscv_pid4063257_axi4_lite_interconnect, rtl_mriscv_pid4063257_apb_bridge, rtl_mriscv_pid4063257_spi_axi_master, rtl_mriscv_pid4063257_sar_adc_10bit, rtl_mriscv_pid4063257_dac_12bit, rtl_mriscv_pid4063257_gpio_8bit, rtl_mriscv_pid4063257_ram_4kb [EXTRACTED 1.00]
- **CIDIC testing board design files** — rtl_mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_schematic, rtl_mriscv_board_pcb_testing_board_cidic_rev_aamaya_brd_top_layout, rtl_mriscv_board_pcb_testing_board_cidic_rev_aamaya_brd_bot_layout, rtl_mriscv_board_eagle_microaxi_pcb1_layout, rtl_mriscv_board_eagle_microaxi_pcb2_layout [INFERRED 0.85]
- **mriscvcore execution/support units** — rtl_mriscv_mriscvcore_alu_instrucciones_alu_alu_module, rtl_mriscv_mriscvcore_deco_instr_decinstdocum_deco_instr_module, rtl_mriscv_mriscvcore_irq_irqmanual_irq_module, rtl_mriscv_mriscvcore_memory_interface_memory_interface_memory_interface_module, rtl_mriscv_mriscvcore_mult_multiplicador_informe_mult_module, rtl_mriscv_mriscvcore_utilities_utilidades_del_procesador___manual_de_usuariov2_0_utility_module [INFERRED 0.85]
- **mRISC-V SoC bus and peripherals** — rtl_mriscv_mriscv_axi_32_bit_100mhz_axi4_lite_bus, rtl_mriscv_mriscv_axi_32_bit_100mhz_apb_bus, rtl_mriscv_mriscv_axi_32_bit_100mhz_sar_adc_10bit, rtl_mriscv_mriscv_axi_32_bit_100mhz_spi_axi_master, rtl_mriscv_mriscv_axi_32_bit_100mhz_spi_axi_slave, rtl_mriscv_mriscv_axi_32_bit_100mhz_ram_4kb [EXTRACTED 1.00]
- **APB peripherals (ADC, DAC, GPIO, SPI slave)** — rtl_mriscv_mriscv_apb_bus, rtl_mriscv_mriscv_adc, rtl_mriscv_mriscv_dac, rtl_mriscv_mriscv_gpio, rtl_mriscv_mriscv_spi_slave [EXTRACTED 1.00]
- **Core datapath (decoder, regs, shift ctrl, ALU)** — rtl_mriscv_mriscv_instruction_decoder, rtl_mriscv_mriscv_cpu_regs, rtl_mriscv_mriscv_shift_ctrl, rtl_mriscv_mriscv_alu [EXTRACTED 1.00]
- **Timer/counters/IRQ/PCPI muxed into result writeback path** — rtl_mriscv_mriscvcore_riscv_core_timer, rtl_mriscv_mriscvcore_riscv_core_cycle_counter, rtl_mriscv_mriscvcore_riscv_core_instr_counter, rtl_mriscv_mriscvcore_riscv_core_irq_handling, rtl_mriscv_mriscvcore_riscv_core_pc [EXTRACTED 1.00]
- **Decode-register-ALU datapath** — rtl_mriscv_mriscvcore_riscv_core_instruction_decoder, rtl_mriscv_mriscvcore_riscv_core_cpu_regs, rtl_mriscv_mriscvcore_riscv_core_shift_ctrl, rtl_mriscv_mriscvcore_riscv_core_alu [EXTRACTED 1.00]

## Communities (74 total, 48 thin omitted)

### Community 0 - "Firmware Apps & HAL"
Cohesion: 0.07
Nodes (44): main(), pwm_all(), main(), main(), main(), main(), main(), gpio2_rd() (+36 more)

### Community 1 - "OLED Encoder Firmware"
Cohesion: 0.11
Nodes (46): draw_value(), int_to_str(), main(), str_len(), val_to_bar(), long_delay(), main(), main() (+38 more)

### Community 2 - "Project Docs & Clock Upgrade"
Cohesion: 0.06
Nodes (47): Clock Upgrade Notes, Core clock 50 MHz via divcnt toggle-FF, Firmware busy-wait delay recalibration (32x), SPI SCLK <= 1/4 core clock rule, mriscv-SPI README, Digilent Basys3 (Artix-7 xc7a35t), basys3_top.v single top-level, Bitstream vs program separation (+39 more)

### Community 3 - "Core Module Docs (ES)"
Cohesion: 0.06
Nodes (32): else, endif, INSTRUCCIONES ALU (ALU manual), ALU module, Multi-cycle shifter (SLL/SRL/SRA), Decodificador de Instrucciones (DecInstDocum), 12-bit instruction encoding (decinst), Instruction decoder (DECO_INSTR) (+24 more)

### Community 4 - "CIDIC Test Board PCB"
Cohesion: 0.07
Nodes (35): microAXI PCB1 layout (cropped), microAXI PCB1 layout, microAXI PCB2 layout (cropped), microAXI PCB2 layout, Testing board PCB layout (bottom), Testing board PCB layout (top: 30MHz osc, CY22150 clock gen, level shifter, LEDs, SMA), ADC/DAC reference & front-end (AD1580, MAX4234, ADA4940), mRISC-V chip pinout (GPIO00-07, SPI AXI slave/master, ADC/DAC, AXI_CLK) (+27 more)

### Community 5 - "SRAM AXI Testbench"
Cohesion: 0.08
Nodes (20): aexpect, AXI_SP32B1024_INTERCONNECT, AXI_SP32B1024_tb, aexpect, xorshift64_next, spi_axi_master_tb, aexpect, xorshift64_next (+12 more)

### Community 6 - "Hex/Upload Python Scripts"
Cohesion: 0.10
Nodes (15): argparse, array, struct, sys, CheetahLink, do_gpio(), do_release(), do_upload() (+7 more)

### Community 7 - "mRISC-V 100MHz Paper"
Cohesion: 0.11
Nodes (23): A 32-bit 100MHz RISC-V Microcontroller with 10-bit SAR ADC in 130nm CMOS, APB bus / APB bridge, AXI4-Lite bus, 130nm CMOS implementation (167uW/MHz, 798x484um), mRISC-V microcontroller, 4kB SRAM, 10-bit SAR ADC, SPI AXI master (programming interface) (+15 more)

### Community 8 - "I2C Master Hardware"
Cohesion: 0.10
Nodes (17): axi_read, axi_write, i2c_master, i2c_master_tb, axi_read, axi_write, check, op (+9 more)

### Community 9 - "Upstream SoC Diagram"
Cohesion: 0.12
Nodes (20): ADC 10-bit 10MS/s, ALU, APB Bus (upstream variant), mriscv SoC Architecture Diagram, AXI4 Bus, mriscv RISC-V Core (CPU block), CPU Register File, DAC 12-bit (+12 more)

### Community 10 - "Basys3 Top & GPIO Bank TB"
Cohesion: 0.14
Nodes (11): check, basys3_top, tb, check, spi_frame, tb, recv_byte, spi_frame (+3 more)

### Community 11 - "LED Show Firmware"
Cohesion: 0.31
Nodes (12): main(), mode_alt(), mode_counter(), mode_fill(), mode_knight(), mode_random(), mode_shift(), rnd8() (+4 more)

### Community 12 - "Cheetah SPI Python API"
Cohesion: 0.15
Nodes (4): cheetah, os, ch_spi_queue_delay_ns(), usage: int return = ch_spi_queue_delay_ns(Cheetah cheetah, int nanoseconds)

### Community 13 - "APB GPIO Composition"
Cohesion: 0.21
Nodes (9): decodificador, flipflopRS, flipsdataw, latchW, macstate2, gpioAPB, gpioAPB_tb, completogpio (+1 more)

### Community 14 - "Encoder OLED Bit-bang"
Cohesion: 0.50
Nodes (12): clear(), cmd(), draw_glyph(), draw_hex2(), i2c_start(), i2c_stop(), i2c_tx(), ihold() (+4 more)

### Community 15 - "ALU Operations"
Cohesion: 0.27
Nodes (11): ALU, ALU_add, ALU_and, ALU_beq, ALU_blt, ALU_bltu, ALU_or, ALU_sub (+3 more)

### Community 16 - "Core Block Diagram"
Cohesion: 0.22
Nodes (13): ALU, CPU Registers (register file), RISC-V Core Block Diagram (riscv_core.png), Instruction Decoder, IRQ Handling, Memory Data Bus, Memory Instr Bus, Memory Interface (+5 more)

### Community 17 - "OLED Test Bit-bang"
Cohesion: 0.50
Nodes (11): cmd(), fill(), i2c_start(), i2c_stop(), i2c_tx(), ihold(), main(), scl() (+3 more)

### Community 18 - "APB Variant SoC"
Cohesion: 0.18
Nodes (6): APB_TOP, picorv32_axi, impl_axi_apb, AXI_SP32B1024, spi_axi_slave, SP32B1024

### Community 19 - "UART TX & Testbench"
Cohesion: 0.22
Nodes (7): begin, end, fork, uart_tx_tb, axi_write, uart_capture, uart_tx

### Community 20 - "impl_axi SoC & UART RX TB"
Cohesion: 0.25
Nodes (5): impl_axi, tb, host_send, spi_frame, spi_axi_master

### Community 21 - "Cheetah Extension Info"
Cohesion: 0.25
Nodes (6): ch_open_ext(), ch_version(), CheetahExt, CheetahVersion, usage: (Cheetah return, CheetahExt ch_ext) = ch_open_ext(int port_number), usage: (int return, CheetahVersion version) = ch_version(Cheetah cheetah)

### Community 22 - "AXI Interconnect Testbench"
Cohesion: 0.33
Nodes (4): axi4_interconnect, axi4_interconnect_tb, aexpect, xorshift64_next

### Community 23 - "Cheetah Device Discovery"
Cohesion: 0.33
Nodes (6): array_u16(), array_u32(), ch_find_devices(), ch_find_devices_ext(), usage: (int return, u16[] devices) = ch_find_devices(u16[] devices) All arrays…, usage: (int return, u16[] devices, u32[] unique_ids) =…

### Community 24 - "Cheetah SPI Batch Transfer"
Cohesion: 0.40
Nodes (5): array_u08(), ch_spi_async_collect(), ch_spi_batch_shift(), usage: (int return, u08[] data_in) = ch_spi_batch_shift(Cheetah cheetah, u08[]…, usage: (int return, u08[] data_in) = ch_spi_async_collect(Cheetah cheetah,…

### Community 30 - "Bus Reset Testbench"
Cohesion: 0.50
Nodes (3): tb, spi_frame, upload

## Ambiguous Edges - Review These
- `ALU` → `PCPI (co-processor interface)`  [AMBIGUOUS]
  rtl/mriscv/mriscvcore/riscv_core.png · relation: conceptually_related_to

## Knowledge Gaps
- **107 isolated node(s):** `install.sh script`, `run.sh script`, `run2.sh script`, `decodificador`, `flipflopRS` (+102 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 246 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **48 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `ALU` and `PCPI (co-processor interface)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `impl_axi` connect `impl_axi SoC & UART RX TB` to `Core Module Docs (ES)`, `I2C Master Hardware`, `Basys3 Top & GPIO Bank TB`, `APB GPIO Composition`, `APB Variant SoC`, `UART TX & Testbench`, `AXI Interconnect Testbench`, `AXI ADC Interface`, `AXI DAC Interface`, `Bus Reset Testbench`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Why does `mriscvcore` connect `Core Module Docs (ES)` to `SRAM AXI Testbench`, `impl_axi SoC & UART RX TB`, `mRISC-V 100MHz Paper`, `ALU Operations`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `ALU` connect `ALU Operations` to `Core Module Docs (ES)`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Are the 23 inferred relationships involving `led_set()` (e.g. with `pwm_all()` and `main()`) actually correct?**
  _`led_set()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `main()` (e.g. with `led_set()` and `ssd1306_begin()`) actually correct?**
  _`main()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 7 inferred relationships involving `main()` (e.g. with `led_set()` and `ssd1306_begin()`) actually correct?**
  _`main()` has 7 INFERRED edges - model-reasoned connections that need verification._