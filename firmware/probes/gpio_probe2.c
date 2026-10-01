#include <stdint.h>
#include "mriscv.h"

/* do-while (backward branch only, SAMA seperti uart_hello.c versi baru)
 * tapi target GPIO. Isolasi: apakah "load+store campur dalam 1 loop"
 * yang bikin hang, independen dari forward-branch maupun UART. */
int main(void) {
    const char *s = "Hi";
    do { gpio_pin(0, 1); s++; } while (*s);

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
