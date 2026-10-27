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

/* ---------------- UART (TX+RX satu slave, 8N1, baud bisa diubah) ----------------
 * Satu slave AXI (uart.v), word 0x4020-0x4023, byte base 0x10080:
 *   +0x0 TXDATA  TULIS byte -> kirim. Transaksi AXI SELALU cepat (non-blocking);
 *                kalau transmitter masih sibuk byte DIABAIKAN hardware, jadi
 *                uart_putc() polling uart_busy() dulu. BACA = STATUS (bit0 busy).
 *   +0x4 RXDATA  BACA = pop: bit[7:0]=byte, bit8=valid, bit9=overrun,
 *                bit10=frame error. Membaca menghapus flag. Holding register
 *                1 byte -- jangan delay lama di loop yang menunggu input.
 *   +0x8 STATUS  BACA (tidak pop): bit0 tx_busy, bit1 rx_valid, bit2 overrun,
 *                bit3 ferr, bit4 rx_busy (sedang menerima frame).
 *   +0xC BAUDDIV clock per bit = UART_CLK_HZ / baud, 16 bit, minimal 16.
 *                Reset = 434 (115200). Tulis DIABAIKAN kalau < 16 atau TX/RX
 *                sedang sibuk -- pakai uart_set_div()/uart_set_baud().
 * BUS_RST (tiap upload firmware) mengembalikan baud ke 115200.
 * Alamat +0/+4 sama dengan uart_tx/uart_rx lama, firmware lama tidak berubah.
 *
 * Catatan riwayat (2026-09-28): versi lama HAL ini memaksa always_inline,
 * membuat uart_puts() dua-fase dengan buffer + delay, dan melarang string
 * >3 karakter karena dugaan "bug core" (REG_FILE, jal/ret, ambang iterasi
 * loop). Dugaan itu TERBANTAH: penyebab hang sebenarnya adalah .bss
 * misaligned di link_c.ld (crt0.S melakukan sw misaligned -> trap sebelum
 * main()). Setelah linker diperbaiki, pola biasa di bawah terbukti jalan
 * di board -- lihat CLAUDE.md bagian "UART hardware". */
#define UART_TXD  (*(volatile unsigned *)(0x10080u))
#define UART_RXR  (*(volatile unsigned *)(0x10084u))
#define UART_STAT (*(volatile unsigned *)(0x10088u))
#define UART_BDIV (*(volatile unsigned *)(0x1008Cu))

#define UART_ST_TXBUSY  0x01u
#define UART_ST_RXVALID 0x02u
#define UART_ST_OVR     0x04u
#define UART_ST_FERR    0x08u
#define UART_ST_RXBUSY  0x10u

/* Clock core -- WAJIB sama dengan CLK_HZ instansiasi uart di impl_axi.v. */
#define UART_CLK_HZ 50000000u
/* Pembagi dibulatkan. HANYA untuk baud KONSTAN (dihitung compiler): dengan
 * variabel runtime, '/' butuh __udivsi3 yang tidak ada (-nostdlib). */
#define UART_DIV(baud) ((UART_CLK_HZ + (baud) / 2u) / (baud))

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

/* Ganti pembagi baud. Menunggu TX selesai (byte terakhir terkirim utuh di
 * baud lama), lalu tulis-dan-baca-balik sampai diterima (ditolak hardware
 * selama RX sedang menerima frame). Return 0 kalau div di luar 16..65535. */
static inline int uart_set_div(unsigned div){
    if (div < 16u || div > 0xFFFFu) return 0;
    while (uart_busy()) {}
    do { UART_BDIV = div; } while (UART_BDIV != div);
    return 1;
}

#define uart_set_baud(baud) uart_set_div(UART_DIV(baud))

/* ---------------- I2C master hardware (400 kHz @ 50 MHz) ----------------
 * Register di byte addr 0x10100 (word 0x4040), 4 register (lihat i2c_master.v):
 *   +0 DATA (tulis: byte TX, baca: byte RX terakhir)
 *   +4 CMD  (bit0 START, bit1 STOP, bit2 WRITE, bit3 READ, bit4 NACK)
 *   +8 STATUS (bit0 busy, bit1 nack, bit2 arb_lost)   +12 DIV
 * Pin = oled_scl/oled_sda (JC1/JC2). Tiap fungsi menunggu engine selesai.
 * i2c_hw_write() return 1 kalau slave ACK, 0 kalau NACK/arbitrasi hilang. */
#define I2C_DATA   (*(volatile unsigned *)(0x10100u))
#define I2C_CMD    (*(volatile unsigned *)(0x10104u))
#define I2C_STATUS (*(volatile unsigned *)(0x10108u))
#define I2C_DIV    (*(volatile unsigned *)(0x1010Cu))
#define I2C_START 0x01u
#define I2C_STOP  0x02u
#define I2C_WRITE 0x04u
#define I2C_READ  0x08u
#define I2C_NACK  0x10u

/* WAJIB dipanggil sekali di awal: GPIO bank 2 reset ke 0 (= SCL/SDA ditarik low
 * lewat wired-AND di top). Tulis 1 melepas pin supaya controller yang mengemudi. */
static inline void i2c_hw_init(void){
    gpio2_pin(GPIO2_OLED_SCL, 1);
    gpio2_pin(GPIO2_OLED_SDA, 1);
}
static inline unsigned i2c__wait(void){
    unsigned s;
    while ((s = I2C_STATUS) & 1u) {}
    return s;
}
/* Kirim 1 byte; flags = kombinasi I2C_START / I2C_STOP. */
static inline int i2c_hw_write(unsigned char b, unsigned flags){
    I2C_DATA = b;
    I2C_CMD  = I2C_WRITE | flags;
    return (i2c__wait() & 6u) == 0;
}
/* Terima 1 byte; last=1 -> kirim NACK (byte terakhir), flags dst. */
static inline unsigned i2c_hw_read(unsigned last, unsigned flags){
    I2C_CMD = I2C_READ | (last ? I2C_NACK : 0u) | flags;
    i2c__wait();
    return I2C_DATA & 0xFFu;
}
static inline void i2c_hw_stop(void){
    I2C_CMD = I2C_STOP;
    i2c__wait();
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