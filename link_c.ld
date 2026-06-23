OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K }
SECTIONS {
  .text 0x0 : { *(.text.init) *(.text*) } > RAM
  .rodata : { *(.rodata*) *(.srodata*) } > RAM
  . = ALIGN(4);
  .init_array : {
    PROVIDE_HIDDEN(__init_array_start = .);
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array))
    PROVIDE_HIDDEN(__init_array_end = .);
  } > RAM
  .data : { *(.data*) *(.sdata*) } > RAM
  . = ALIGN(4);
  .bss : {
    PROVIDE(__bss_start = .);
    *(.sbss*) *(.bss*) *(COMMON)
    . = ALIGN(4);
    PROVIDE(__bss_end = .);
  } > RAM
  . = ALIGN(4);
  PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));
}
