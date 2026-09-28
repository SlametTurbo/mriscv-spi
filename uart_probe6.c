#include <stdint.h>
#include "mriscv.h"

/* Isolasi lanjutan: uart_puts() + led_set() ASLI (loop 8x GPIO write,
 * bukan cuma 1 gpio_pin()) diulang terus-menerus. */
int main(void) {
    uint8_t v = 0;
    for (;;) {
        uart_puts("X\r\n");
        led_set(v);
        v++;
        delay(0x300000);
    }
}
