#include <stdint.h>
#include "mriscv.h"

/* Isolasi lanjutan: DUA kali tulis UART beruntun (tanpa delay di antaranya),
 * lalu counting LED. Kalau ini hang tapi uart_probe.c (1x tulis) tidak,
 * berarti bug-nya spesifik di WRITE KEDUA saat transmitter masih busy. */
int main(void) {
    uart_putc('X');
    uart_putc('Y');

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
