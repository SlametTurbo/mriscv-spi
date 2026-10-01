#!/bin/bash
cd /home/adhitiya/mriscv-spi
for s in $(seq 1 20); do
  nextpnr-xilinx --chipdb ../chipdb//xc7a35tcpg236.bin --xdc basys3_spi.xdc --json basys.json --fasm seedsweep/s$s.fasm --freq 50 --seed $s > seedsweep/s$s.log 2>&1
  echo "$s $(grep 'Max frequency for clock' seedsweep/s$s.log | grep \"'clk'\" | tail -1)" >> seedsweep/results.txt
done
echo DONE >> seedsweep/results.txt
