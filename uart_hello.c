#include <stdint.h>
#include "mriscv.h"

/* Kirim tiap karakter literal langsung (uart_putc() always_inline, TANPA
 * loop atas string, TANPA panggil uart_puts()). Ini satu-satunya pola yang
 * terbukti SELALU aman di hardware -- lihat CLAUDE.md bagian "UART hardware
 * (TX-only)" untuk kronologi lengkap kenapa uart_puts(char*) TIDAK dipakai
 * di sini (ambang ~3 iterasi loop sebelum core hang, bug hardware yang
 * belum terpecahkan). */
static void send_hello(void){
    uart_putc('H'); uart_putc('e'); uart_putc('l'); uart_putc('l');
    uart_putc('o'); uart_putc(' '); uart_putc('U'); uart_putc('A');
    uart_putc('R'); uart_putc('T'); uart_putc(' '); uart_putc('@');
    uart_putc(' '); uart_putc('m'); uart_putc('r'); uart_putc('i');
    uart_putc('s'); uart_putc('c'); uart_putc('v'); uart_putc('\r');
    uart_putc('\n');
}

int main(void) {
    uint8_t v = 0;
    for (;;) {
        send_hello();
        led_set(v);   // LED nunjukin loop masih hidup
        v++;
        delay(0x300000);
    }
}
