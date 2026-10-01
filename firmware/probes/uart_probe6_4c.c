#include <stdint.h>
#include "mriscv.h"

/* EKSPERIMEN clock 25 MHz (2026-09-28): salinan uart_probe6.c, string diganti
 * "0123" (4 karakter) -- pola yang di 50 MHz TERBUKTI langsung hang.
 * Hasil yang diharapkan kalau hipotesis timing benar: LED terus menghitung
 * dan "0123" berulang muncul di serial (115200 8N1). */
int main(void) {
    uint8_t v = 0;
    for (;;) {
        uart_puts("0123");
        led_set(v);
        v++;
        delay(0x300000);
    }
}
