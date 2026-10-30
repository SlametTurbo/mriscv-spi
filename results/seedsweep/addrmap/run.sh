#!/bin/bash
# Sweep seed P&R untuk peta alamat baru (2026-10-30). Netlist Yosys sama (basys.json
# disalin di folder ini), hanya seed nextpnr yang berubah. 4 run paralel.
cd /home/adhitiya/mriscv-spi
D=results/seedsweep/addrmap
seq 1 20 | xargs -P4 -I{} sh -c "nextpnr-xilinx --chipdb ../chipdb/xc7a35tcpg236.bin --xdc rtl/basys3_spi.xdc --json $D/basys.json --fasm $D/s{}.fasm --freq 50 --seed {} > $D/s{}.log 2>&1"
for s in $(seq 1 20); do
  echo "$s $(grep 'Max frequency for clock' $D/s$s.log | grep "'clk'" | tail -1 | sed 's/.*: //')"
done > $D/results.txt
