#include <stdint.h>
#include "mriscv.h"

/* Echo UART RX->TX: tiap byte yang diterima dikirim balik, dan 8 bit
 * bawahnya ditampilkan di LED. Kirim "?" untuk melihat statistik overrun/
 * frame error sejak boot. Terminal: 115200 8N1 di /dev/ttyUSB1. */
int main(void) {
    unsigned ovr = 0, ferr = 0;
    uart_puts("UART echo siap\r\n");
    for (;;) {
        unsigned v = UART_RXR;
        if (!(v & 0x100u)) continue;
        if (v & 0x200u) ovr++;
        if (v & 0x400u) ferr++;
        char c = (char)(v & 0xFFu);
        led_set((unsigned)(unsigned char)c);
        if (c == '?') {
            uart_puts("ovr="); uart_putc((char)('0' + (ovr > 9 ? 9 : ovr)));
            uart_puts(" ferr="); uart_putc((char)('0' + (ferr > 9 ? 9 : ferr)));
            uart_puts("\r\n");
        } else uart_putc(c);
    }
}
