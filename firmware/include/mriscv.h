#ifndef MRISCV_H
#define MRISCV_H
/* ============================================================================
 * mriscv.h -- helper GPIO untuk core mriscv (RV32I) @ Basys3
 *
 * (Bank 2 untuk encoder + OLED: lihat bagian GPIO BANK 2 di bawah.)
 * GPIO bit-addressed: pin i pada alamat byte (0x10040 + i*4), i = 0..7.
 *   (base direlokasi dari 0x1040 -> 0x10040 setelah SRAM diperbesar 4 KB -> 32 KB,
 *    supaya tidak tabrakan dengan rentang alamat SRAM yang baru)
 *   - TULIS : 0x3 = nyala (data=1, enable/DSE=1)
 *             0x2 = mati  (data=0, enable=1)        -> datanw[i] (output: LED, dsb)
 *   - BACA  : bit0 hasil load = pindata[i]          (input: switch, encoder, dsb)
 * ============================================================================ */

#define GPIO(i)  (*(volatile unsigned *)(0x10040u + (unsigned)(i) * 4u))

/* ---------------- OUTPUT (tulis) ---------------- */

/* set 1 pin output: val = 0 (mati) / 1 (nyala) */
static inline void gpio_pin(unsigned i, unsigned val){
    GPIO(i) = (val & 1u) | 0x2u;
}

/* tulis nilai 8-bit ke datanw[7:0] (tampil di LED & seven-seg sbg hex) */
static inline void led_set(unsigned v){
    for (unsigned i = 0; i < 8u; i++) gpio_pin(i, (v >> i) & 1u);
}

/* alias 8-bit bus (kompatibilitas program lama) */
static inline void gpio_bus(unsigned v){ led_set(v); }

/* ---------------- INPUT (baca) ---------------- */

/* baca 1 pin input -> 0 / 1  (mis. switch atau sinyal encoder) */
static inline unsigned gpio_rd(unsigned i){
    return GPIO(i) & 1u;
}

/* baca 8 pin input sekaligus -> nilai 8-bit (pin i di bit i) */
static inline unsigned gpio_bus_rd(void){
    unsigned v = 0;
    for (unsigned i = 0; i < 8u; i++) v |= (gpio_rd(i) & 1u) << i;
    return v;
}

/* alias tulis 1 pin (sebagian program memakai nama ini) */
static inline void gpio_wr(unsigned i, unsigned v){ gpio_pin(i, v); }

/* ---------------- GPIO BANK 2 (encoder + OLED I2C) ----------------
 * Slave AXI kedua, byte 0x100C0 + i*4, i = 0..7. Semantik tulis/baca SAMA dengan
 * bank 1. Pemakaian di top module (basys3_top.v):
 *   baca : pin 0 = encoder CLK, pin 1 = encoder DT
 *   tulis: pin 0 = OLED SCL,    pin 1 = OLED SDA (open-drain: 1 = lepas, 0 = low)
 * Bank 1 (switch/LED/7-seg) tidak terganggu. */
#define GPIO2(i) (*(volatile unsigned *)(0x100C0u + (unsigned)(i) * 4u))
#define GPIO2_ENC_CLK 0u
#define GPIO2_ENC_DT  1u
#define GPIO2_OLED_SCL 0u
#define GPIO2_OLED_SDA 1u

static inline void gpio2_pin(unsigned i, unsigned val){ GPIO2(i) = (val & 1u) | 0x2u; }
static inline unsigned gpio2_rd(unsigned i){ return GPIO2(i) & 1u; }

/* ---------------- util ---------------- */

static inline void delay(volatile unsigned n){ while (n--) __asm__ volatile(""); }

/* ---------------- UART (TX-only, 115200 8N1 fixed) ----------------
 * Register di byte addr 0x10080 (word 0x4020, tepat setelah GPIO).
 *   TULIS byte apapun -> kirim 1 byte lewat UART. Transaksi AXI SELALU cepat
 *     (non-blocking di level hardware, persis seperti GPIO) -- kalau
 *     transmitter masih sibuk, byte yang ditulis diam-diam DIABAIKAN oleh
 *     hardware. uart_putc() di bawah POLLING uart_busy() di SOFTWARE dulu
 *     sebelum tulis, supaya byte tidak pernah hilang.
 *   BACA -> bit0 = busy (1 = masih transmit).
 * Baud rate di-hardcode di RTL (uart_tx.v, CLK_HZ=50MHz/BAUD=115200,
 * DIV=434, error real-baud ~0.0064%). Kalau clock core diubah, parameter
 * CLK_HZ di impl_axi.v WAJIB disesuaikan juga.
 *
 * Catatan riwayat (2026-09-28): versi lama HAL ini memaksa always_inline,
 * membuat uart_puts() dua-fase dengan buffer + delay, dan melarang string
 * >3 karakter karena dugaan "bug core" (REG_FILE, jal/ret, ambang iterasi
 * loop). Dugaan itu TERBANTAH: penyebab hang sebenarnya adalah .bss
 * misaligned di link_c.ld (crt0.S melakukan sw misaligned -> trap sebelum
 * main()). Setelah linker diperbaiki, pola biasa di bawah terbukti jalan
 * di board -- lihat CLAUDE.md bagian "UART hardware". */
#define UART_TXD (*(volatile unsigned *)(0x10080u))

static inline unsigned uart_busy(void){
    return UART_TXD & 1u;
}

static inline void uart_putc(char c){
    while (uart_busy()) {}
    UART_TXD = (unsigned)(unsigned char)c;
}

static inline void uart_puts(const char *s){
    while (*s) uart_putc(*s++);
}

/* ---------------- UART RX (115200 8N1 fixed) ----------------
 * Register di byte addr 0x10084 (word 0x4021). BACA = pop:
 *   bit[7:0]=byte, bit8=valid, bit9=overrun, bit10=frame error.
 * Membaca menghapus flag. Holding register 1 byte -- jangan delay lama di
 * loop yang menunggu input, atau byte berikutnya menimpa (overrun). */
#define UART_RXR (*(volatile unsigned *)(0x10084u))

/* Non-blocking: return byte (0-255), atau -1 kalau belum ada. */
static inline int uart_getc_nb(void){
    unsigned v = UART_RXR;
    return (v & 0x100u) ? (int)(v & 0xFFu) : -1;
}

/* Blocking: tunggu sampai ada byte. */
static inline char uart_getc(void){
    int c;
    while ((c = uart_getc_nb()) < 0) {}
    return (char)c;
}

/* ---------------- Counter siklus / instruksi (CSR read-only) ----------------
 * rdcycle = siklus clock core (50 MHz) sejak reset, rdinstret = jumlah
 * instruksi, rdtime = +1 tiap 101 siklus (bukan waktu nyata). Butuh RTL dengan
 * fix CSRRS di UTILITY.v (2026-09-28) -- di bitstream lama instruksi ini bikin
 * CPU macet. Counter 64-bit; di sini cuma 32 bit bawah (wrap ~86 s @50MHz),
 * pakai selisih unsigned (akhir - awal) supaya aman melewati wrap.
 * always_inline: cuma 1 instruksi, jadi selalu lebih murah di-inline. */
static inline __attribute__((always_inline)) unsigned rdcycle(void){
    unsigned v; __asm__ volatile("rdcycle %0" : "=r"(v)); return v;
}
static inline __attribute__((always_inline)) unsigned rdinstret(void){
    unsigned v; __asm__ volatile("rdinstret %0" : "=r"(v)); return v;
}

#endif /* MRISCV_H */