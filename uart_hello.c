#include <stdint.h>
#include "mriscv.h"

/* Kirim string lewat UART (115200 8N1) berulang, LED menghitung sebagai
 * tanda loop masih hidup. */
int main(void) {
    uint8_t v = 0;
    for (;;) {
        uart_puts("Hello UART @ mriscv\r\n");
        led_set(v);
        v++;
        delay(0x300000);
    }
}
