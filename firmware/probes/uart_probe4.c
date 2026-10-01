#include <stdint.h>
#include "mriscv.h"

/* uart_puts() lewat LOOP asli tapi cuma 1 karakter -- isolasi apakah
 * LOOP-nya sendiri (branch/pointer) yang bermasalah, atau soal jumlah
 * tulisan berulang (uart_probe3.c pakai 4 karakter dan hang). */
int main(void) {
    uart_puts("H");

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
