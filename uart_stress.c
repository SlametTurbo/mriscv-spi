#include <stdint.h>
#include "mriscv.h"

/* Uji stres HAL UART (2026-09-28): string runtime panjang lewat uart_puts()
 * + angka hasil hitungan (baca-tulis register & RAM terus-menerus), tanpa
 * delay, dipanggil berulang. Di era dugaan "bug core" semua pola ini
 * dilarang; setelah fix .bss di link_c.ld harus jalan terus-menerus.
 * Output: "#<n hex 8 digit> The quick brown fox ... 0123456789\r\n". */
static void put_hex(unsigned v){
    for (int i = 28; i >= 0; i -= 4) {
        unsigned d = (v >> i) & 0xFu;
        uart_putc((char)(d < 10u ? '0' + d : 'A' + d - 10u));
    }
}

int main(void) {
    unsigned n = 0;
    for (;;) {
        uart_putc('#');
        put_hex(n);
        uart_puts(" The quick brown fox jumps over the lazy dog 0123456789\r\n");
        led_set(n);
        n++;
    }
}
