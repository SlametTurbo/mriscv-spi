# =====================================================================
# fw.mk - Build firmware C/C++ bare-metal untuk mriscv -> firmware.hex
# Pakai:   make -f fw.mk                 (default SRC=main.c)
#          make -f fw.mk SRC=main.cpp    (C++)
#          make -f fw.mk clean
# Hasil firmware.hex diletakkan di folder ini (dibaca SP32B1024.v saat 'make' bitstream)
# =====================================================================
PREFIX  ?= riscv64-unknown-elf-
SRC     ?= main.c
CRT     := crt0.S
LD      := link_c.ld

CFLAGS  := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Os -Wall
CXXADD  := -fno-exceptions -fno-rtti -fno-threadsafe-statics

EXT := $(suffix $(SRC))
ifeq ($(EXT),.cpp)
  CC := $(PREFIX)g++
  FLAGS := $(CFLAGS) $(CXXADD)
else ifeq ($(EXT),.cc)
  CC := $(PREFIX)g++
  FLAGS := $(CFLAGS) $(CXXADD)
else
  CC := $(PREFIX)gcc
  FLAGS := $(CFLAGS)
endif

firmware.hex: prog.bin
	@python3 -c "import struct;d=open('prog.bin','rb').read();d+=b'\\0'*((-len(d))%4);open('firmware.hex','w').write(''.join('%08x\\n'%struct.unpack('<I',d[i:i+4])[0] for i in range(0,len(d),4)))"
	@echo "OK -> firmware.hex ($$(wc -l < firmware.hex) kata, $$(wc -c < prog.bin) byte)"

prog.bin: prog.elf
	$(PREFIX)objcopy -O binary prog.elf prog.bin

prog.elf: $(CRT) $(SRC) $(LD)
	$(CC) $(FLAGS) -T $(LD) $(CRT) $(SRC) -o prog.elf
	@$(PREFIX)size prog.elf

clean:
	rm -f prog.elf prog.bin firmware.hex

.PHONY: clean
