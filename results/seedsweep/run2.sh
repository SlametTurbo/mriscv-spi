#!/bin/zsh
cd /home/adhitiya/mriscv-spi
rm -f basys.json basys.fasm basys.frames basys.bit
make basys.json XDC=basys3_spi.xdc > seedsweep/yosys2.log 2>&1 || { echo YOSYS_FAIL > seedsweep/res2.txt; exit 1; }
mkdir -p seedsweep/u; rm -f seedsweep/u/*
for s in $(seq 1 20); do
  nextpnr-xilinx --chipdb ../chipdb//xc7a35tcpg236.bin --xdc basys3_spi.xdc --json basys.json --fasm seedsweep/u/s$s.fasm --freq 50 --seed $s > seedsweep/u/s$s.log 2>&1
  echo "$s $(grep 'Max frequency for clock' seedsweep/u/s$s.log | grep "'clk'" | tail -1 | sed 's/.*: //')" >> seedsweep/res2.txt
done
echo DONE >> seedsweep/res2.txt
