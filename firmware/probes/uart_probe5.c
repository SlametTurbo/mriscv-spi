#include <stdint.h>
#include "mriscv.h"

/* Eksperimen: apakah loop "baca RAM -> tulis RAM lokal (buffer)" -- BUKAN ke
 * peripheral -- juga kena bug yang sama? Kalau LED tetap hidup/counting,
 * berarti loop baca+tulis SRAM-ke-SRAM aman, dan kandidat solusi robust
 * uart_puts() adalah: buffer dulu (loop 1, SRAM-only), baru tulis ke UART
 * tanpa polling (loop 2, write-only + delay, tanpa baca sama sekali). */
#define BUFMAX 32
int main(void) {
    const char *s = "Hi there\r\n";
    static volatile char buf[BUFMAX];  /* volatile: cegah GCC hapus loop ini
                                           (dead-code-elim krn buf tak dibaca) */
    unsigned n = 0;

    /* loop 1: PURE baca+tulis SRAM (tidak sentuh peripheral sama sekali) */
    while (n < BUFMAX - 1 && s[n]) { buf[n] = s[n]; n++; }

    /* loop 2: baca dari buffer (slave 0/SRAM) -> tulis ke UART (slave 5),
     * TANPA polling busy (write-only ke peripheral, no read balik dari
     * peripheral). Ini tes: apakah "baca slave 0, tulis slave LAIN" dalam
     * loop rapat yang jadi masalah (bukan cuma soal SRAM vs peripheral). */
    for (unsigned i = 0; i < n; i++) {
        UART_TXD = (unsigned)(unsigned char)buf[i];
        delay(20000);
    }

    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }
}
