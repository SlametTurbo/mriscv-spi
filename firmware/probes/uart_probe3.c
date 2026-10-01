#include <stdint.h>
#include "mriscv.h"

/* String pendek (4 char) lewat uart_puts() (LOOP asli, bukan manual
 * inline call) -- beda dari uart_probe2.c yang manual 2x uart_putc(). */
int main(void) {
    uart_puts("Hi\r\n");

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
