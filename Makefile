# Build mriscv minimum system untuk Basys3 dengan openXC7 (TANPA Vivado)
FAMILY  = artix7
PART    = xc7a35tcpg236-1
BOARD   = basys3
PROJECT = spi
TOP     = basys3_top
XDC     = basys3_spi.xdc

ADDITIONAL_SOURCES = \
  SP32B1024.v \
  mriscv/mriscv_axi/impl_axi/impl_axi.v \
  mriscv/mriscv_axi/axi4_interconnect/axi4_interconnect.v \
  mriscv/mriscv_axi/AXI_SP32B1024/AXI_SP32B1024.v \
  mriscv/mriscv_axi/spi_axi_master/spi_axi_master.v \
  mriscv/mriscv_axi/spi_axi_slave/spi_axi_slave.v \
  mriscv/mriscv_axi/DAC_interface_AXI/DAC_interface_AXI.v \
  mriscv/mriscv_axi/ADC_interface_AXI/ADC_interface_AXI.v \
  mriscv/mriscv_axi/GPIO/completogpio.v \
  mriscv/mriscv_axi/GPIO/decodificador.v \
  mriscv/mriscv_axi/GPIO/flipflopRS.v \
  mriscv/mriscv_axi/GPIO/flipsdataw.v \
  mriscv/mriscv_axi/GPIO/latchW.v \
  mriscv/mriscv_axi/GPIO/macstate2.v \
  mriscv/mriscv_axi/util/bus_sync_sf.v \
  mriscv/mriscv_axi/util/priencr.v \
  mriscv/mriscvcore/mriscvcore.v \
  mriscv/mriscvcore/ALU/ALU.v \
  mriscv/mriscvcore/DECO_INSTR/DECO_INSTR.v \
  mriscv/mriscvcore/FSM/FSM.v \
  mriscv/mriscvcore/IRQ/IRQ.v \
  mriscv/mriscvcore/MEMORY_INTERFACE/MEMORY_INTERFACE.v \
  mriscv/mriscvcore/MULT/MULT.v \
  mriscv/mriscvcore/REG_FILE/REG_FILE.v \
  mriscv/mriscvcore/UTILITIES/UTILITY.v

include ../openXC7.mk
