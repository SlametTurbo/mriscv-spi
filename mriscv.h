#ifndef MRISCV_H
#define MRISCV_H
#include <stdint.h>
/* =====================================================================
 * mriscv.h - helper bare-metal untuk sistem mriscv di Basys3
 *
 * GPIO mriscv bersifat bit-addressed: tiap "pin" menyimpan 1 bit data.
 * Pin i berada di byte 0x1040 + i*4.  Wdata[0]=data, Wdata[1]=DSE(enable).
 * Nilai data muncul di output completogpio.datanw[i] (-> LED / 7seg / dst).
 * ===================================================================== */

#define GPIO_BASE 0x1040u
#define GPIO(i)   (*(volatile uint32_t *)(GPIO_BASE + (i)*4u))

/* Tulis 1 bit (0/1) ke pin GPIO ke-i. DSE selalu aktif. */
static inline void gpio_pin(unsigned i, unsigned val) {
    GPIO(i) = (val & 1u) | 0x2u;        /* 0x3 = on, 0x2 = off */
}

/* Tulis nilai 'value' ke pin 0..nbits-1 (LSB ke pin0).
   Dipakai untuk: LED bar 8-bit, atau angka ke 7-segment (di-decode hardware). */
static inline void gpio_bus(uint32_t value, unsigned nbits) {
    for (unsigned i = 0; i < nbits; i++)
        gpio_pin(i, (value >> i) & 1u);
}

/* Delay sibuk (jumlah iterasi). ~1.5 MHz clock: ~30000-ish ~ 0.1 s.
   Atur angkanya untuk mengubah kecepatan; nilai pasti tergantung CPI core. */
static inline void delay(volatile uint32_t n) {
    while (n--) __asm__ volatile ("");
}

/* Helper LED 8-bit (alias gpio_bus value,8). */
static inline void led_set(uint8_t v) { gpio_bus(v, 8); }

#endif /* MRISCV_H */
