#include <stdint.h>
#include "mriscv.h"

/* EKSPERIMEN clock 25 MHz (2026-09-28): gabungan SEMUA pola yang di 50 MHz
 * terbukti bikin hang, sengaja dalam satu program:
 *   - fungsi putc NON-inline (jal/ret sungguhan, tulis-lalu-baca ra),
 *   - polling busy UART (baca AXI -> tulis AXI),
 *   - string runtime dibaca dari RAM lewat pointer (lbu), >3 karakter.
 * Hasil yang diharapkan kalau hipotesis timing benar: LED terus menghitung
 * dan "Hello UART @ mriscv 25MHz" berulang muncul di serial (115200 8N1). */
static __attribute__((noinline)) void putc_call(char c){
    while (uart_busy()) {}
    UART_TXD = (unsigned)(unsigned char)c;
}

static __attribute__((noinline)) void puts_call(const char *s){
    while (*s) putc_call(*s++);
}

int main(void) {
    uint8_t v = 0;
    for (;;) {
        puts_call("Hello UART @ mriscv 25MHz\r\n");
        led_set(v);
        v++;
        delay(0x100000);
    }
}
