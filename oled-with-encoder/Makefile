# ==============================================================================
# Makefile VARIAN: oled-with-encoder
# Subfolder di dalam mriscv-spi. Berbagi RTL/openXC7.mk/chipdb/cheetah dengan
# parent (lewat $(SHARED)=..), tapi memakai top/XDC/program LOKAL folder ini.
#
# Jalankan DARI DALAM folder ini:
#   make synth          - bitstream OLED (spi.bit di folder ini)
#   make flash          - flash ke board
#   make prog FW=encoder_oled   - compile + upload program via SPI
#   make prog FW=oled_test      - uji OLED menyala penuh
# ==============================================================================

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Lokasi sumber daya BERSAMA (di parent mriscv-spi). Ubah bila beda.
# ------------------------------------------------------------------------------
SHARED       ?= ..

# ------------------------------------------------------------------------------
# (A) Variabel openXC7.mk
# ------------------------------------------------------------------------------
PROJECT      := spi
PART         := xc7a35tcpg236-1
FAMILY       := artix7
BOARD        := basys3

# Top & XDC LOKAL folder ini (varian OLED)
TOP          := basys3_top
TOP_MODULE   := basys3_top
TOP_VERILOG  := basys3_top.v
XDC          ?= basys3_oled.xdc

# RTL diambil dari parent. SP32B1024.v (BRAM behavioral) juga di parent.
MRISCV       ?= $(SHARED)/mriscv
SP32B1024    ?= $(SHARED)/SP32B1024.v
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
ADDITIONAL_SOURCES := $(SP32B1024) $(filter-out %_tb.v,$(RTL_RAW))

# openXC7.mk & chipdb ada di level demo-projects (satu lvl di atas parent).
OPENXC7_MK   ?= $(SHARED)/../openXC7.mk
# Pakai chipdb BERSAMA milik demo-projects (jangan regenerate).
CHIPDB       ?= $(SHARED)/../chipdb

# ------------------------------------------------------------------------------
# (B) Firmware & uploader SPI (infrastruktur BERSAMA dari parent)
# ------------------------------------------------------------------------------
FW           ?= encoder_oled
CRT          := $(SHARED)/crt0.S
LDS          := $(SHARED)/link_c.ld
HDR          := $(SHARED)/mriscv.h

RISCV_PREFIX ?= riscv64-unknown-elf
CC           := $(RISCV_PREFIX)-gcc
OBJCOPY      := $(RISCV_PREFIX)-objcopy
OBJDUMP      := $(RISCV_PREFIX)-objdump
SIZE         := $(RISCV_PREFIX)-size
# -I$(SHARED) supaya #include "mriscv.h" ketemu header bersama
CFLAGS       := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Os -Wall -I$(SHARED)

ELF_FILE     := $(FW).elf
BIN_FILE     := $(FW).bin

# uploader cheetah dari parent
SPI_UPLOAD   := python3 $(SHARED)/cheetah_mriscv.py
# kHz; <= ~200 utk core /64
SPI_BITRATE  ?= 100

# ------------------------------------------------------------------------------
# (C) Target firmware / upload (nama BERBEDA dari openXC7.mk)
# ------------------------------------------------------------------------------
.PHONY: synth flash build upload prog gpio release clean-fw help check-fw

## synth: bangun bitstream varian OLED (aturan openXC7.mk)
synth: $(PROJECT).bit

## flash: upload bitstream ke board
flash: program

## build: compile FW=<nama>.c (lokal folder ini) -> <nama>.bin
build: check-fw $(BIN_FILE)

$(ELF_FILE): $(FW).c $(CRT) $(LDS) $(HDR)
	@echo "==== COMPILE FIRMWARE: $(FW).c ===="
	$(CC) $(CFLAGS) -T $(LDS) $(CRT) $(FW).c -o $(ELF_FILE)
	@$(SIZE) $(ELF_FILE)

$(BIN_FILE): $(ELF_FILE)
	$(OBJCOPY) -O binary $(ELF_FILE) $(BIN_FILE)
	@echo "[OK] $(BIN_FILE)  ($$(wc -c < $(BIN_FILE)) byte)"

## upload: upload <nama>.bin via SPI
upload: check-fw
	@[ -f "$(BIN_FILE)" ] || { echo "[ERR] $(BIN_FILE) tdk ada. Jalankan: make build FW=$(FW)"; exit 1; }
	@echo "==== UPLOAD via SPI: $(BIN_FILE) ===="
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) upload $(BIN_FILE)

## prog: compile + upload via SPI
prog: build upload

## gpio / release (via SPI host bersama)
PIN ?= 0
STATE ?= on
gpio:
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) gpio $(PIN) $(STATE)
release:
	$(SPI_UPLOAD) --bitrate $(SPI_BITRATE) release

## clean-fw: hapus artefak firmware lokal (bitstream pakai 'make clean' openXC7.mk)
clean-fw:
	rm -f *.elf *.bin
	@echo "[OK] firmware bersih."

check-fw:
	@if [ ! -f "$(FW).c" ]; then \
		echo "[ERR] $(FW).c tidak ada di folder ini. Tentukan: make $(MAKECMDGOALS) FW=<nama>"; \
		echo "      Tersedia: $$(ls *.c 2>/dev/null | sed 's/\.c//' | tr '\n' ' ')"; \
		exit 1; fi

## help
help:
	@echo ""
	@echo "Varian: oled-with-encoder (subfolder mriscv-spi)"
	@echo "================================================"
	@echo "  make synth                  bitstream OLED -> spi.bit"
	@echo "  make flash                  flash ke board"
	@echo "  make prog FW=oled_test      uji OLED nyala penuh"
	@echo "  make prog FW=encoder_oled   encoder -> angka di OLED"
	@echo "  make clean (bitstream) | make clean-fw (firmware)"
	@echo ""
	@echo "Program lokal: $$(ls *.c 2>/dev/null | sed 's/\.c//' | tr '\n' ' ')"
	@echo "Sumber bersama dari: $(SHARED)  (RTL, openXC7.mk, chipdb, cheetah, crt0/linker/header)"
	@echo ""

# ------------------------------------------------------------------------------
# (D) Alur bitstream openXC7 (all, program, *.json/fasm/frames/bit, chipdb, clean)
# ------------------------------------------------------------------------------
include $(OPENXC7_MK)