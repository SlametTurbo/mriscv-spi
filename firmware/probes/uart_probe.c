#include <stdint.h>
#include "mriscv.h"

/* Isolasi: SATU kali tulis UART, lalu counting LED terus-menerus.
 * Kalau LED counting normal setelah ini -> AXI write ke UART SUKSES (tidak hang).
 * Kalau LED mati/diam -> AXI write ke UART yang bikin macet. */
int main(void) {
    uart_putc('X');          /* satu kali tulis, nilai bebas */

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
