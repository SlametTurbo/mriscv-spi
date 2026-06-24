# ==============================================================================
# Makefile — mriscv-spi (RV32I @ Basys3)
# Menggabungkan 4 fungsi dalam satu berkas:
#   (1) sintesis bitstream   (2) flash bitstream
#   (3) compile program C    (4) upload program via SPI
#
# Alur bitstream DIDELEGASIKAN ke openXC7.mk resmi (terbukti + auto-generate
# chipdb), lalu target firmware/upload ditambahkan di atasnya.
# ==============================================================================
#
#   make synth   XDC=basys3_switch.xdc     - sintesis -> spi.bit
#   make flash                             - upload bitstream ke board (JTAG)
#   make build   FW=<nama>                 - compile <nama>.c -> <nama>.bin
#   make upload  FW=<nama>                 - upload <nama>.bin via SPI
#   make prog    FW=<nama>                 - compile + upload via SPI
#   make allflow FW=<nama> XDC=basys3_switch.xdc  - synth + flash + prog
#   make gpio PIN=0 STATE=on               - set 1 pin GPIO via SPI
#   make release                           - lepas core (PICORV_RST=1)
#   make clean        (bitstream)  |  make clean-fw (firmware)
# ==============================================================================

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# (A) Variabel yang dibaca openXC7.mk  - definisikan SEBELUM include
# ------------------------------------------------------------------------------
PROJECT      := spi
PART         := xc7a35tcpg236-1
FAMILY       := artix7
BOARD        := basys3

# Top module proyek (override default ${PROJECT}.v di openXC7.mk)
TOP          := basys3_top
TOP_MODULE   := basys3_top
TOP_VERILOG  := basys3_top.v

# XDC: default LED; untuk switch -> 'make synth XDC=basys3_switch.xdc'
XDC          ?= basys3_spi.xdc

# Semua sumber Verilog SELAIN top -> ADDITIONAL_SOURCES (dibaca openXC7.mk).
# Top + BRAM behavioral di folder ini; sisanya dari repo mriscv. _tb.v dibuang.
MRISCV       ?= mriscv
RTL_DIRS := \
	$(MRISCV)/mriscv_axi/impl_axi \
	$(MRISCV)/mriscv_axi/axi4_interconnect \
	$(MRISCV)/mriscv_axi/AXI_SP32B1024 \
	$(MRISCV)/mriscv_axi/spi_axi_master \
	$(MRISCV)/mriscv_axi/spi_axi_slave \
	$(MRISCV)/mriscv_axi/DAC_interface_AXI \
	$(MRISCV)/mriscv_axi/ADC_interface_AXI \
	$(MRISCV)/mriscv_axi/GPIO \
	$(MRISCV)/mriscv_axi/util \
	$(MRISCV)/mriscvcore \
	$(MRISCV)/mriscvcore/ALU \
	$(MRISCV)/mriscvcore/DECO_INSTR \
	$(MRISCV)/mriscvcore/FSM \
	$(MRISCV)/mriscvcore/IRQ \
	$(MRISCV)/mriscvcore/MEMORY_INTERFACE \
	$(MRISCV)/mriscvcore/MULT \
	$(MRISCV)/mriscvcore/REG_FILE \
	$(MRISCV)/mriscvcore/UTILITIES
RTL_RAW            := $(foreach d,$(RTL_DIRS),$(wildcard $(d)/*.v))
ADDITIONAL_SOURCES := SP32B1024.v $(filter-out %_tb.v,$(RTL_RAW))

# Lokasi openXC7.mk (struktur demo-projects: satu level di atas project).
OPENXC7_MK   ?= ../openXC7.mk

# ------------------------------------------------------------------------------
# (B) Variabel firmware & uploader SPI
# ------------------------------------------------------------------------------
FW           ?= main
CRT          := crt0.S
LDS          := link_c.ld
HDR          := mriscv.h

RISCV_PREFIX ?= riscv64-unknown-elf
CC           := $(RISCV_PREFIX)-gcc
OBJCOPY      := $(RISCV_PREFIX)-objcopy
OBJDUMP      := $(RISCV_PREFIX)-objdump
SIZE         := $(RISCV_PREFIX)-size
CFLAGS       := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Os -Wall

ELF_FILE     := $(FW).elf
BIN_FILE     := $(FW).bin

SPI_UPLOAD   := python3 cheetah_mriscv.py
# kHz; <= ~200 utk core /64
SPI_BITRATE  ?= 100

# ------------------------------------------------------------------------------
# (C) Target firmware / upload / konvenien  (nama BERBEDA dari openXC7.mk)
# ------------------------------------------------------------------------------
.PHONY: synth flash build upload prog allflow gpio release clean-fw help check-fw check-tools

## synth: bangun bitstream (memakai aturan openXC7.mk)
synth: $(PROJECT).bit

## flash: upload bitstream ke board (alias ke target 'program' openXC7.mk)
flash: program

## build: compile FW=<nama> -> <nama>.bin
build: check-fw $(BIN_FILE)

$(ELF_FILE): $(FW).c $(CRT) $(LDS) $(HDR)
	@echo "==== COMPILE FIRMWARE: $(FW).c ===="
	$(CC) $(CFLAGS) -T $(LDS) $(CRT) $(FW).c -o $(ELF_FILE)
	@$(SIZE) $(ELF_FILE)
	@$(OBJDUMP) -d $(ELF_FILE) > $(FW).dump

$(BIN_FILE): $(ELF_FILE)
	$(OBJCOPY) -O binary $(ELF_FILE) $(BIN_FILE)
	@echo "[OK] $(BIN_FILE)  ($$(wc -c < $(BIN_FILE)) byte)"

## upload: upload <nama>.bin via SPI (subcommand 'upload' wajib)
upload: check-fw
	@[ -f "$(BIN_FILE)" ] || { echo "[ERR] $(BIN_FILE) tdk ada. Jalankan: make build FW=$(FW)"; exit 1; }
	@echo "==== UPLOAD PROGRAM via SPI: $(BIN_FILE) ===="
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) upload $(BIN_FILE)

## prog: compile + upload via SPI (tanpa rebuild bitstream)
prog: build upload

## allflow: synth + flash + compile + upload (lengkap dari nol)
allflow: synth flash prog

## gpio: set 1 pin GPIO langsung via SPI  (make gpio PIN=0 STATE=on)
PIN   ?= 0
STATE ?= on
gpio:
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) gpio $(PIN) $(STATE)

## release: lepas core (PICORV_RST=1)
release:
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) release

## clean-fw: hapus artefak firmware (bitstream pakai 'make clean' dari openXC7.mk)
clean-fw:
	rm -f *.elf *.bin *.dump
	@echo "[OK] firmware bersih."

check-fw:
	@if [ ! -f "$(FW).c" ]; then \
		echo "[ERR] $(FW).c tidak ada. Tentukan: make $(MAKECMDGOALS) FW=<nama>"; \
		echo "      Tersedia: $$(ls *.c 2>/dev/null | sed 's/\.c//' | tr '\n' ' ')"; \
		exit 1; fi

check-tools:
	@for t in yosys nextpnr-xilinx fasm2frames xc7frames2bit openFPGALoader pypy3 $(CC); do \
		command -v $$t >/dev/null 2>&1 && echo "  [ok] $$t" || echo "  [MISSING] $$t"; done

## help: panduan
help:
	@echo ""
	@echo "mriscv-spi - Makefile terpadu (include openXC7.mk)"
	@echo "=================================================="
	@echo "  make synth   XDC=basys3_switch.xdc   sintesis -> spi.bit"
	@echo "  make flash                           upload bitstream ke board"
	@echo "  make build FW=<nama>                 compile <nama>.c -> .bin"
	@echo "  make upload FW=<nama>                upload .bin via SPI"
	@echo "  make prog  FW=<nama>                 compile + upload via SPI"
	@echo "  make allflow FW=<nama> XDC=...       synth + flash + prog"
	@echo "  make gpio PIN=0 STATE=on  |  make release"
	@echo "  make clean (bitstream)    |  make clean-fw (firmware)"
	@echo ""
	@echo "Contoh program switch:"
	@echo "  make synth XDC=basys3_switch.xdc && make flash"
	@echo "  make prog FW=switch_led_satu"
	@echo ""
	@echo "Firmware tersedia: $$(ls *.c 2>/dev/null | sed 's/\.c//' | tr '\n' ' ')"
	@echo ""
	@echo "CATATAN:"
	@echo "  - Butuh openXC7.mk di $(OPENXC7_MK) (repo openXC7/demo-projects)."
	@echo "    Override: make synth OPENXC7_MK=/path/ke/openXC7.mk"
	@echo "  - chipdb di-generate otomatis sekali (beberapa menit) ke ../chipdb/."
	@echo "    Pastikan folder ../chipdb/ ada:  mkdir -p ../chipdb"
	@echo "  - Setelah board mati/nyala -> 'make flash' dulu (SRAM volatile)."
	@echo ""

# ------------------------------------------------------------------------------
# (D) Sertakan alur bitstream resmi openXC7 (menyediakan: all, program,
#     $(PROJECT).{json,fasm,frames,bit}, chipdb, clean, pnrclean)
# ------------------------------------------------------------------------------
include $(OPENXC7_MK)