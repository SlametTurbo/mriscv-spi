#include <stdint.h>
#include "mriscv.h"

/* WORKAROUND (2026-09-28): setiap karakter ditulis literal langsung, TANPA
 * baca memori runtime sama sekali (bukan lewat uart_puts()/loop atas
 * string). Bug core yang belum terpecahkan bikin loop apapun yang baca
 * data (termasuk baca karakter dari string di RAM) lalu tulis peripheral
 * hang permanen di hardware -- lihat CLAUDE.md bagian "UART hardware
 * (TX-only)" untuk kronologi lengkap. Pola literal-only ini identik dengan
 * uart_probe2.c yang sudah berkali-kali terbukti aman di hardware asli. */
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
