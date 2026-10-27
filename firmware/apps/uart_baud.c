#include <stdint.h>
#include "mriscv.h"

/* Demo register BAUDDIV UART di board. SW1:SW0 memilih baud:
 *   00 = 115200   01 = 9600   10 = 230400   11 = 921600
 * Saat switch berubah, pesan "-> pindah ke ..." dikirim DI BAUD LAMA, lalu
 * baud diganti -- ganti juga baud terminal (mis. screen /dev/ttyUSB1 9600).
 * Secara berkala (kira-kira 0.2-0.5 detik) kirim baris "#<hitungan hex> @<baud> div=<hex>", dan
 * karakter yang diketik di terminal di-echo balik (LED = byte terakhir). */

static const unsigned    divs[4]  = { UART_DIV(115200u), UART_DIV(9600u),
                                      UART_DIV(230400u), UART_DIV(921600u) };
static const char *const names[4] = { "115200", "9600", "230400", "921600" };

static void put_hex(unsigned v, unsigned ndig) {
    for (int s = (int)(ndig * 4u) - 4; s >= 0; s -= 4) {
        unsigned d = (v >> s) & 0xFu;
        uart_putc((char)(d < 10u ? '0' + d : 'A' + d - 10u));
    }
}

static unsigned sel_rd(void) { return gpio_rd(0) | (gpio_rd(1) << 1); }

int main(void) {
    unsigned sel = sel_rd(), n = 0, t = 0;
    uart_set_div(divs[sel]);
    uart_puts("\r\nuart_baud siap @"); uart_puts(names[sel]); uart_puts("\r\n");

    for (;;) {
        unsigned s = sel_rd();
        if (s != sel) {
            uart_puts("-> pindah ke "); uart_puts(names[s]); uart_puts("\r\n");
            sel = s;
            uart_set_div(divs[sel]);
            uart_puts("baud sekarang "); uart_puts(names[sel]); uart_puts("\r\n");
        }

        int c = uart_getc_nb();
        if (c >= 0) { led_set((unsigned)c); uart_putc((char)c); }

        if (++t == 200000u) {                 /* berkala, tergantung lama 1 iterasi */
            t = 0;
            uart_putc('#'); put_hex(n++, 4);
            uart_puts(" @"); uart_puts(names[sel]);
            uart_puts(" div="); put_hex(UART_BDIV, 4); uart_puts("\r\n");
        }
    }
}
