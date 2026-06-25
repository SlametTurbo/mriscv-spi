/* encoder_7seg.c -- rotary encoder KY-040 -> seven-segment (hex counter).
 *   pindata[0]=CLK,  pindata[1]=DT.
 *   Putar searah jarum jam -> counter naik; sebaliknya -> turun.
 *   Counter 8-bit (membungkus 00..FF). Untuk reset: tekan btnC lalu upload ulang,
 *   atau lihat varian dgn switch-reset di bawah.
 *
 *   CATATAN: pin SW encoder TIDAK dipakai sebagai reset, karena pin yang
 *   mengambang/low memicu reset terus-menerus.
 */
#include "mriscv.h"
#define ENC_CLK 0
#define ENC_DT  1

int main(void){
    int count = 0;
    int shown = -1;                          /* paksa tampil pertama kali */
    unsigned last_clk = gpio_rd(ENC_CLK);

    for(;;){
        unsigned clk = gpio_rd(ENC_CLK);
        if (last_clk == 1u && clk == 0u){    /* tepi turun CLK */
            if (gpio_rd(ENC_DT)) count++;    /* CW  */
            else                 count--;    /* CCW */
        }
        last_clk = clk;

        if (count != shown){                 /* tulis seven-seg hanya saat berubah */
            led_set((unsigned)count & 0xFF);
            shown = count;
        }
    }
}