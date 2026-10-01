/* encoder_test.c -- DIAGNOSTIK: tampilkan keadaan pin input mentah di seven-seg.
 *   bit0=CLK, bit1=DT, bit2=SW.  Putar encoder -> digit kanan berubah 0..3.
 *   Tekan tombol -> bit2 (tambah 4). Kalau TIDAK berubah sama sekali = jalur
 *   baca/wiring bermasalah. Kalau berubah = core baca OK (bug ada di logika).
 */
#include "mriscv.h"
int main(void){
    for(;;){ led_set(gpio_bus_rd()); }
}