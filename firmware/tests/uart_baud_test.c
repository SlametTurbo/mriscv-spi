#include <stdint.h>
#include "mriscv.h"

/* Uji regresi controller UART (uart.v): register BAUDDIV + TX/RX di baud baru.
 * Dipakai impl_axi_uartbaud_tb.v (simulasi SoC), bisa juga di board (terminal
 * harus ikut pindah baud, jadi lebih enak pakai uart_baud.c untuk board).
 * Urutan di TXD:
 *   "A115\r\n"  @115200
 *   "B230\r\n"  @230400, lalu 4 byte dari host @230400 di-echo balik
 *   "C115\r\n"  @115200 lagi
 * LED: 0x5A = lulus, 0x80|err = gagal (bit err lihat di bawah). */
int main(void) {
    unsigned err = 0;

    if (UART_BDIV != 434u) err |= 1;          /* nilai reset = 115200 */
    uart_puts("A115\r\n");

    if (!uart_set_baud(230400)) err |= 2;
    if (UART_BDIV != 217u) err |= 2;
    if (uart_set_div(15)) err |= 4;           /* HAL menolak < 16 */
    UART_BDIV = 15;                           /* hardware juga menolak */
    if (UART_BDIV != 217u) err |= 4;
    uart_puts("B230\r\n");

    for (unsigned k = 0; k < 4; k++) {
        unsigned v;
        while (!((v = UART_RXR) & 0x100u)) {}
        if (v & 0x600u) err |= 8;             /* overrun / frame error */
        uart_putc((char)(v & 0xFFu));
    }
    if (UART_STAT & (UART_ST_OVR | UART_ST_FERR)) err |= 8;

    uart_set_baud(115200);
    if (UART_BDIV != 434u) err |= 2;
    uart_puts("C115\r\n");

    led_set(err ? (0x80u | err) : 0x5Au);
    for (;;) {}
}
