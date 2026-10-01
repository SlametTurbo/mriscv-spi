# Graph Report - mriscv-spi  (2026-09-28)

## Corpus Check
- Large corpus: 151 files · ~3,684,563 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 524 nodes · 672 edges · 63 communities (19 shown, 44 thin omitted)
- Extraction: 88% EXTRACTED · 10% INFERRED · 1% AMBIGUOUS · INFERRED: 69 edges (avg confidence: 0.85)
- Token cost: 652,915 input · 0 output

## Community Hubs (Navigation)
- ALU & Instruction Decoder
- AXI/APB Top-Level Integration & Lessons
- GPIO/LED Demo Firmware
- TRNG Research & Bus Architecture
- Physical Test Board (PCB/Schematics)
- Synthesis Benchmarks & Project Findings
- SPI Uploader Tool (cheetah_mriscv.py)
- Core Architecture Diagram (mriscv.jpg)
- AXI SRAM & SPI Master Testbenches
- UART TX Hardware & Testbench
- Cheetah Python Array Types
- GPIO AXI Submodules (completogpio)
- ALU RTL Module
- LED Show Demo Firmware
- Open-V / Onchip Ecosystem Docs
- Cheetah Device Open/Version API
- Cheetah Device Discovery API
- Cheetah SPI Batch/Async API
- ADC APB Interface
- DAC APB Interface
- APB Top-Level Testbench
- AXI Top-Level Testbench
- Seven-Segment Demo Firmware
- APB Interconnect RTL
- Priority Encoder Utility
- Cheetah API: ch_close
- Cheetah API: ch_dev_addr
- Cheetah API: ch_host_ifce_speed
- Cheetah API: ch_open
- Cheetah API: ch_port
- Cheetah API: ch_sleep_ms
- Cheetah API: ch_spi_async_submit
- Cheetah API: ch_spi_batch_length
- Cheetah API: ch_spi_bitrate
- Cheetah API: ch_spi_configure
- Cheetah API: ch_spi_queue_array
- Cheetah API: ch_spi_queue_byte
- Cheetah API: ch_spi_queue_clear
- Cheetah API: ch_spi_queue_delay_cycles
- Cheetah API: ch_spi_queue_oe
- Cheetah API: ch_spi_queue_ss
- Cheetah API: ch_status_string
- Cheetah API: ch_target_power
- Cheetah API: ch_unique_id
- Install Script
- GPIO APB Submodule: decodificador
- GPIO APB Submodule: flipflopRS
- GPIO APB Submodule: flipsdataw
- GPIO APB Submodule: latchW
- GPIO APB Submodule: macstate2
- GPIO AXI Submodule: decodificador
- GPIO AXI Submodule: flipflopRS
- GPIO AXI Submodule: flipsdataw
- GPIO AXI Submodule: latchW
- GPIO AXI Submodule: macstate2
- Bus Sync Utility
- seecode.sh Script
- MAX4234RU Op-Amp Component
- PCB Training Header Block

## God Nodes (most connected - your core abstractions)
1. `led_set()` - 17 edges
2. `mriscv-spi Project Overview` - 16 edges
3. `impl_axi` - 15 edges
4. `ALU` - 15 edges
5. `mriscv CPU Core (yellow block)` - 13 edges
6. `mriscvcore` - 11 edges
7. `RISC-V Core Block Diagram` - 11 edges
8. `mriscvcore_tb` - 10 edges
9. `mRISC-V Microcontroller` - 9 edges
10. `CIDIC MCU block (chip under test)` - 9 edges

## Surprising Connections (you probably didn't know these)
- `AXI_SP32B1024 Negedge Timing Design (Intentional)` --references--> `AXI_SP32B1024`  [AMBIGUOUS]
  CLAUDE.md → mriscv/mriscv_axi/AXI_SP32B1024/AXI_SP32B1024.v
- `UART TX Hardware Implementation` --references--> `uart_tx`  [AMBIGUOUS]
  CLAUDE.md → mriscv/mriscv_axi/UART_TX/uart_tx.v
- `axi4_interconnect Missing Parameter Override Bug` --references--> `axi4_interconnect`  [AMBIGUOUS]
  CLAUDE.md → mriscv/mriscv_axi/axi4_interconnect/axi4_interconnect.v
- `axi4_interconnect Missing Parameter Override Bug` --references--> `impl_axi`  [AMBIGUOUS]
  CLAUDE.md → mriscv/mriscv_axi/impl_axi/impl_axi.v
- `Troubleshooting Guide` --semantically_similar_to--> `Things That Must Not Be Broken (JANGAN DIRUSAK)`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **UART Hang Debugging Investigation** — claude_uart_tx_hardware, claude_axi4_interconnect_param_bug, claude_reg_file_fragility_bug, claude_gcc_inline_workaround, claude_uart_debug_saga [INFERRED 0.85]
- **Fmax / Timing Margin Investigation Across Docs** — claude_fmax_variability, claude_nextpnr_seed_determinism, benchmark_summary_fmax_determinism_finding, seed_summary_seed_sensitivity_finding, clock_upgrade_margin_analysis [INFERRED 0.85]
- **Verify-Before-Claim Lessons** — claude_verify_before_claim_principle, claude_axi_sp32b1024_negedge, claude_axi4_interconnect_param_bug [EXTRACTED 1.00]
- **mRISC-V dual-bus AXI4-Lite/APB peripheral architecture** — mriscv_pid4063257_mrisc_v, mriscv_pid4063257_axi4lite, mriscv_pid4063257_apb, mriscv_pid4063257_apb_bridge, mriscv_pid4063257_spi_master [EXTRACTED 0.95]
- **Testing board connector blocks feeding CIDIC MCU chip under test** — mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_cidic_mcu, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_spi_programming_interface, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_slave_spi_conn, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_adc_conn, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_dac_conn, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_gpio_conn [EXTRACTED 0.90]
- **SPI-based programming and peripheral verification flow (simulation testbench and physical test board)** — mriscv_pid4063257_testbench, mriscv_pid4063257_spi_master, mriscv_board_schematics_testing_board_cidic_rev_aamaya_sch_spi_programming_interface [INFERRED 0.85]
- **Onchip Web IDE -> Ticket -> SPI Programming Flow** — mriscv_demo1_onchip_web_platform, mriscv_demo1_blink_led_demo, mriscv_demo1_ticket_system, mriscv_demo1_spi_programming_flow [INFERRED 0.80]
- **mRISC-V Analog/Mixed-Signal Peripheral Set** — mriscv_mriscv_axi_32_bit_100mhz_mriscv_microcontroller, mriscv_mriscv_axi_32_bit_100mhz_sar_adc_10bit, mriscv_mriscv_axi_32_bit_100mhz_dac_12bit, mriscv_mriscv_axi_32_bit_100mhz_gpio_module [EXTRACTED 1.00]
- **TRNG Entropy-Extraction-PostProcessing Pipeline** — mriscv_fully_synthesized_trng_fully_synthesized_trng, mriscv_fully_synthesized_trng_three_edge_ring_oscillator, mriscv_fully_synthesized_trng_capture_stage, mriscv_fully_synthesized_trng_cellular_automata_post_processing [EXTRACTED 1.00]
- **Instruction decode (codif/opcode) feeding ALU and UTILITY execution stages** — mriscv_mriscvcore_deco_instr_decinstdocum_decodificador_de_instrucciones, mriscv_mriscvcore_alu_instrucciones_alu_manual_del_alu, mriscv_mriscvcore_utilities_utilidades_del_procesador_manual_de_usuariov2_0_utility_manual [INFERRED 0.80]
- **RV32M multiply extension: decoder encoding + multiplier design + unused RTL module** — mriscv_mriscvcore_deco_instr_decinstdocum_riscv_instruction_encoding_table, mriscv_mriscvcore_mult_multiplicador_informe_bloque_multiplicador, mriscv_mriscvcore_mult_mult_mult [INFERRED 0.85]
- **Interrupt handling: IRQ block instructions, decoder encoding of IRQ opcodes, UTILITY PC redirection** — mriscv_mriscvcore_irq_irqmanual_irq_manual, mriscv_mriscvcore_deco_instr_decinstdocum_decodificador_de_instrucciones, mriscv_mriscvcore_utilities_utilidades_del_procesador_manual_de_usuariov2_0_pc_control_logic [INFERRED 0.80]

## Communities (63 total, 44 thin omitted)

### Community 0 - "ALU & Instruction Decoder"
Cohesion: 0.05
Nodes (48): ALU Arithmetic/Logical/Comparison Operations, Manual del A.L.U, Rationale: dedicated 'En' input gates multi-cycle shifts to avoid wasted cycles/resources, ALU Shift Operations (SLL/SRL/SRA), Decodificador de Instrucciones (Instruction Decoder Manual), Invalid Instruction Handling (unrecognized inst -> codif=4095, all 1s), RISC-V 49-Instruction 12-bit Encoding Table (funct+opcode), DECO_INSTR (+40 more)

### Community 1 - "AXI/APB Top-Level Integration & Lessons"
Cohesion: 0.05
Nodes (34): APB_TOP, axi4_interconnect, basys3_top, axi4_interconnect Missing Parameter Override Bug, AXI_SP32B1024 Negedge Timing Design (Intentional), Things That Must Not Be Broken (JANGAN DIRUSAK), Verify Before Claiming Done/Bug Principle, impl_axi_apb (+26 more)

### Community 2 - "GPIO/LED Demo Firmware"
Cohesion: 0.10
Nodes (26): main(), pwm_all(), main(), main(), main(), main(), main(), delay() (+18 more)

### Community 3 - "TRNG Research & Bus Architecture"
Cohesion: 0.06
Nodes (40): TRNG ASIC Implementation (130nm CMOS, 170x58um), Capture Stage (cycle counter + PFD), Cellular-Automata Post-Processing (Rule_X), TRNG FPGA Implementation (Spartan 3AN), Fully-Synthesized TRNG (130nm CMOS), Jitter Accumulation / Edge Collapse Mechanism, NIST Randomness Test Suite Verification, 3-Edge Ring Oscillator Entropy Source (+32 more)

### Community 4 - "Physical Test Board (PCB/Schematics)"
Cohesion: 0.07
Nodes (38): microAXI PCB1 (cropped) - Top Layer Render, rev 2016-08-12, microAXI PCB1 - Top Layer Render, rev 2016-08-12, microAXI PCB2 (cropped) - Bottom Layer Render, rev 2016-08-12, microAXI PCB2 - Bottom Layer Render, rev 2016-08-12, Testing Board CIDIC (rev aamaya) - PCB Bottom Copper Layer, Testing Board CIDIC (rev aamaya) - PCB Top Copper Layer, AD1580ARTZ Precision Voltage Reference, ADA4940 Differential Amplifier (ADC driver) (+30 more)

### Community 5 - "Synthesis Benchmarks & Project Findings"
Cohesion: 0.08
Nodes (36): Finding: nextpnr Fmax Deterministic for Fixed RTL, Synthesis Benchmark Methodology, Config: new_32kb_50mhz, Config: old_4kb_1.5mhz, FPGA Resource Utilization Comparison, AXI Address Map (Post RAM Expansion), AXI Bus Used, APB Variant Unused, Clock Core Upgrade to 50 MHz (+28 more)

### Community 6 - "SPI Uploader Tool (cheetah_mriscv.py)"
Cohesion: 0.10
Nodes (15): argparse, array, CheetahLink, do_gpio(), do_release(), do_upload(), DryRun, frame_bytes() (+7 more)

### Community 7 - "Core Architecture Diagram (mriscv.jpg)"
Cohesion: 0.11
Nodes (21): ADC 10bit 10MS/s block, ALU block, APB bus, AXI4 bus, mriscv.jpg — Core Architecture Block Diagram, mriscv CPU Core (yellow block), CPU REGS (register file) block, Cycle Counter block (+13 more)

### Community 8 - "AXI SRAM & SPI Master Testbenches"
Cohesion: 0.10
Nodes (13): aexpect, AXI_SP32B1024_INTERCONNECT, AXI_SP32B1024_tb, aexpect, xorshift64_next, spi_axi_master_tb, aexpect, xorshift64_next (+5 more)

### Community 9 - "UART TX Hardware & Testbench"
Cohesion: 0.11
Nodes (15): begin, else, end, endif, fork, uart_tx_tb, axi_write, uart_capture (+7 more)

### Community 10 - "Cheetah Python Array Types"
Cohesion: 0.15
Nodes (4): cheetah, ch_spi_queue_delay_ns(), usage: int return = ch_spi_queue_delay_ns(Cheetah cheetah, int nanoseconds), os

### Community 11 - "GPIO AXI Submodules (completogpio)"
Cohesion: 0.21
Nodes (9): decodificador, flipflopRS, flipsdataw, latchW, macstate2, gpioAPB, gpioAPB_tb, completogpio (+1 more)

### Community 12 - "ALU RTL Module"
Cohesion: 0.27
Nodes (11): ALU, ALU_add, ALU_and, ALU_beq, ALU_blt, ALU_bltu, ALU_or, ALU_sub (+3 more)

### Community 13 - "LED Show Demo Firmware"
Cohesion: 0.38
Nodes (9): main(), mode_alt(), mode_counter(), mode_fill(), mode_knight(), mode_random(), mode_shift(), rnd8() (+1 more)

### Community 14 - "Open-V / Onchip Ecosystem Docs"
Cohesion: 0.24
Nodes (10): Blink LED Demo, Onchip Web IDE Platform (onchip.uis.edu.co), Open-V Microcontroller (dev board target), USB-to-SPI Programming Flow, Board Access Ticket System, Design Skills Venn Diagram (PeripheralRISCV copy), RISC-V Recommends: Open-IP Bus Table, Open-V Crowd Supply Campaign (+2 more)

### Community 15 - "Cheetah Device Open/Version API"
Cohesion: 0.25
Nodes (6): ch_open_ext(), ch_version(), CheetahExt, CheetahVersion, usage: (Cheetah return, CheetahExt ch_ext) = ch_open_ext(int port_number), usage: (int return, CheetahVersion version) = ch_version(Cheetah cheetah)

### Community 16 - "Cheetah Device Discovery API"
Cohesion: 0.33
Nodes (6): array_u16(), array_u32(), ch_find_devices(), ch_find_devices_ext(), usage: (int return, u16[] devices) = ch_find_devices(u16[] devices) All arrays…, usage: (int return, u16[] devices, u32[] unique_ids) =…

### Community 17 - "Cheetah SPI Batch/Async API"
Cohesion: 0.40
Nodes (5): array_u08(), ch_spi_async_collect(), ch_spi_batch_shift(), usage: (int return, u08[] data_in) = ch_spi_batch_shift(Cheetah cheetah, u08[]…, usage: (int return, u08[] data_in) = ch_spi_async_collect(Cheetah cheetah,…

### Community 22 - "Seven-Segment Demo Firmware"
Cohesion: 0.83
Nodes (3): delay(), main(), tampilkan_ke_hardware()

## Ambiguous Edges - Review These
- `AXI_SP32B1024` → `AXI_SP32B1024 Negedge Timing Design (Intentional)`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `uart_tx` → `UART TX Hardware Implementation`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `axi4_interconnect` → `axi4_interconnect Missing Parameter Override Bug`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `impl_axi` → `axi4_interconnect Missing Parameter Override Bug`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `FSM` → `PC (Program Counter) Block`  [AMBIGUOUS]
  mriscv/mriscvcore/riscv_core.png · relation: implements
- `IRQ` → `Timer Block`  [AMBIGUOUS]
  mriscv/mriscvcore/riscv_core.png · relation: implements
- `IRQ.v Timer Interrupt Controller Disabled` → `weas.txt Disassembly Test Dump (ddr2.o)`  [AMBIGUOUS]
  mriscv/mriscvcore/tests/weas.txt · relation: conceptually_related_to
- `mriscv.jpg — Core Architecture Block Diagram` → `APB bus`  [AMBIGUOUS]
  mriscv/mriscv.jpg · relation: conceptually_related_to
- `mriscv.jpg — Core Architecture Block Diagram` → `RAM 4KB block (diagram)`  [AMBIGUOUS]
  mriscv/mriscv.jpg · relation: conceptually_related_to

## Knowledge Gaps
- **95 isolated node(s):** `install.sh script`, `decodificador`, `flipflopRS`, `flipsdataw`, `latchW` (+90 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 226 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **44 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `AXI_SP32B1024` and `AXI_SP32B1024 Negedge Timing Design (Intentional)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `uart_tx` and `UART TX Hardware Implementation`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `axi4_interconnect` and `axi4_interconnect Missing Parameter Override Bug`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `impl_axi` and `axi4_interconnect Missing Parameter Override Bug`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `FSM` and `PC (Program Counter) Block`?**
  _Edge tagged AMBIGUOUS (relation: implements) - confidence is low._
- **What is the exact relationship between `IRQ` and `Timer Block`?**
  _Edge tagged AMBIGUOUS (relation: implements) - confidence is low._
- **What is the exact relationship between `IRQ.v Timer Interrupt Controller Disabled` and `weas.txt Disassembly Test Dump (ddr2.o)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._