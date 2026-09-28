#ifndef MRISCV_H
#define MRISCV_H
/* ============================================================================
 * mriscv.h -- helper GPIO untuk core mriscv (RV32I) @ Basys3
 *
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

/* ---------------- util ---------------- */

static inline void delay(volatile unsigned n){ while (n--) __asm__ volatile(""); }

/* ---------------- UART (TX-only, 9600 8N1 fixed) ----------------
 * Register di byte addr 0x10080 (word 0x4020, tepat setelah GPIO).
 *   TULIS byte apapun -> kirim 1 byte lewat UART. Transaksi AXI SELALU cepat
 *     (non-blocking di level hardware, persis seperti GPIO) -- kalau
 *     transmitter masih sibuk, byte yang ditulis diam-diam DIABAIKAN oleh
 *     hardware. uart_putc() di bawah POLLING uart_busy() di SOFTWARE dulu
 *     sebelum tulis, supaya byte tidak pernah hilang.
 *   BACA -> bit0 = busy (1 = masih transmit).
 * Baud rate di-hardcode di RTL (uart_tx.v, CLK_HZ=50MHz/BAUD=9600) -- kalau
 * clock core proyek diubah, parameter CLK_HZ di impl_axi.v WAJIB disesuaikan.
 *
 * CATATAN DESAIN (2026-09-28, penting -- dua percobaan sebelumnya GAGAL di
 * hardware nyata meski lolos simulasi & elaborate check):
 *   Desain awal uart_tx.v BLOCKING di level hardware (AXI write ditahan
 *   sampai byte terkirim, ~52080 siklus @ 9600bps/50MHz) -- ini TERBUKTI
 *   bikin CPU macet permanen begitu program menulis >1 byte, meski logika-
 *   nya lolos testbench terisolasi. Root cause pastinya belum 100% pasti
 *   (dugaan: masalah timing marginal/metastabilitas yang cuma muncul kalau
 *   sinyal AXI ditahan konstan puluhan ribu siklus berturut-turut -- bukan
 *   sesuatu yang kelihatan dari Fmax/static timing biasa), tapi FIX-nya
 *   jelas: uart_tx.v sekarang didesain ulang supaya TIDAK PERNAH menahan
 *   bus AXI lama sama sekali (selalu selesai dalam beberapa siklus, sama
 *   seperti GPIO/DAC/ADC yang sudah terbukti aman). "Tunggu transmitter
 *   idle" dipindah ke polling software di sini, bukan bus-stall hardware.
 * -------------------------------------------------------------------- */
#define UART_TXD (*(volatile unsigned *)(0x10080u))

/* __attribute__((always_inline)) WAJIB di sini (2026-09-28): GCC -Os
 * ternyata TIDAK selalu meng-inline fungsi "inline" biasa kalau dipanggil
 * berkali-kali (>~3x) -- malah di-compile jadi jal/ret sungguhan. jal/ret
 * berulang (tulis rd=ra lalu nanti baca ra utk ret) ternyata JUGA memicu
 * bug core yang sama dengan pola baca-lalu-tulis AXI (lihat CLAUDE.md).
 * always_inline memaksa GCC selalu inline penuh, menghilangkan jal/ret
 * sama sekali -- cocok dengan pola uart_probe2.c yang terbukti aman. */
static inline __attribute__((always_inline)) unsigned uart_busy(void){
    return UART_TXD & 1u;
}

static inline __attribute__((always_inline)) void uart_putc(char c){
    while (uart_busy()) {}
    UART_TXD = (unsigned)(unsigned char)c;
}

/* ---- uart_puts(): WORKAROUND, BUKAN fix akar masalah (2026-09-28) ----
 * uart_putc() SENDIRI aman dipanggil sekali (uart_probe.c teruji OK). Tapi
 * pola LOOP yang baca *s lalu tulis UART lalu baca *s berikutnya lagi --
 * apapun bentuknya, bahkan cuma 1 karakter -- TERBUKTI bikin CPU core hang
 * permanen di hardware asli (lihat CLAUDE.md bagian "UART hardware (TX-only)"
 * untuk kronologi lengkap: bug ini BUKAN spesifik UART, GPIO polos kena juga,
 * root cause di CPU core belum ketemu meski margin timing sudah bagus &
 * uart_tx.v sudah non-blocking).
 *
 * uart_puts() DIHINDARI polling uart_busy() di dalam loop (mengurangi jumlah
 * baca AXI per iterasi dari 2 jadi 1) dan pakai delay() tetap (>1 periode
 * baud @ 9600bps = ~1.04ms) sebagai ganti nunggu busy clear. Ini BELUM
 * terbukti 100% aman untuk SEMUA panjang string -- kalau mulai hang lagi,
 * itu bukti bug core ini masih ada & workaround ini cuma mengurangi risiko,
 * bukan menghilangkan. Kalibrasi delay: sesuaikan DELAY_PER_CHAR di bawah
 * kalau observasi di serial terminal menunjukkan karakter hilang/gepeng. */
#define UART_DELAY_PER_CHAR 20000u
static inline void uart_puts(const char *s){
    do {
        UART_TXD = (unsigned)(unsigned char)*s;
        delay(UART_DELAY_PER_CHAR);
        s++;
    } while (*s);
}

#endif /* MRISCV_H */