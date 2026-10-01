#include <stdint.h>
#include "mriscv.h"

/* Tiru persis struktur loop uart_puts("H") tapi target-nya GPIO, bukan UART.
 * Kalau ini JUGA hang, berarti bug-nya di CPU/branch, bukan di uart_tx.v. */
int main(void) {
    const char *s = "H";
    while (*s) { gpio_pin(0, 1); s++; }

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
