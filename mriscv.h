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

/* ---------------- UART (TX-only, 115200 8N1 fixed) ----------------
 * Register di byte addr 0x10080 (word 0x4020, tepat setelah GPIO).
 *   TULIS byte apapun -> kirim 1 byte lewat UART. Transaksi AXI SELALU cepat
 *     (non-blocking di level hardware, persis seperti GPIO) -- kalau
 *     transmitter masih sibuk, byte yang ditulis diam-diam DIABAIKAN oleh
 *     hardware. uart_putc() di bawah POLLING uart_busy() di SOFTWARE dulu
 *     sebelum tulis, supaya byte tidak pernah hilang.
 *   BACA -> bit0 = busy (1 = masih transmit).
 * Baud rate di-hardcode di RTL (uart_tx.v, CLK_HZ=50MHz/BAUD=115200) --
 * dinaikkan dari 9600 (2026-09-28), DIV=434, error real-baud ~0.0064%,
 * jauh di bawah toleransi UART standar (~2%). Kalau clock core proyek
 * diubah, parameter CLK_HZ di impl_axi.v WAJIB disesuaikan juga.
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

/* ---- uart_puts(): dua-fase, TAPI MASIH TIDAK SEPENUHNYA AMAN (2026-09-28) --
 * ==========================================================================
 * ⚠️  JANGAN PAKAI uart_puts() UNTUK STRING >3 KARAKTER. GUNAKAN uart_putc()
 * ⚠️  LITERAL BERULANG TANPA LOOP (lihat pola send_hello() di uart_hello.c)
 * ⚠️  UNTUK SEMUA KEBUTUHAN NYATA. Ini satu-satunya pola yang TERBUKTI
 * ⚠️  SELALU aman di hardware.
 * ==========================================================================
 * Kronologi (baca CLAUDE.md bagian "UART hardware (TX-only)" utk detail):
 *   - Loop baca-RAM -> tulis-RAM-lokal (SRAM-ke-SRAM)                 -> AMAN.
 *   - Loop baca-buffer(SRAM) -> tulis-UART TANPA polling busy         -> AMAN
 *     (utk string PENDEK).
 *   - TAPI begitu diuji dgn loop yg IKUT MENGULANG whole dance (uart_puts
 *     dipanggil berulang dlm for(;;)), ketemu AMBANG BATAS YANG SANGAT
 *     SPESIFIK: loop di dalam uart_puts() aman kalau iterasi <=3, TAPI
 *     HANG kalau iterasi >=4 -- diverifikasi dengan disassembly BYTE-PER-
 *     BYTE IDENTIK antara string 3 karakter (aman) vs 4 karakter (hang),
 *     cuma beda ISI DATA string-nya, bukan kode yg dijalankan. ROOT CAUSE
 *     PASTI belum ketemu (kemungkinan counter/state internal beberapa bit
 *     yang wrap di iterasi ke-4 -- butuh logic analyzer/ILA utk pasti,
 *     di luar jangkauan sesi debugging ini).
 *
 * uart_puts() di bawah TETAP menerapkan pola dua-fase (baca RAM->buffer,
 * lalu buffer->UART tanpa polling) karena itu strictly LEBIH AMAN daripada
 * desain sebelumnya, TAPI CUMA cocok utk string SANGAT PENDEK (<=3 char).
 * Kalau butuh kirim string lebih panjang SEKALI PAKAI (bukan dipanggil
 * berulang dalam loop luar), mungkin masih aman -- TAPI BELUM DIUJI
 * SECARA MENYELURUH, jangan asumsikan aman tanpa tes hardware langsung. */
#define UART_BUF_MAX 128u
#define UART_DELAY_PER_CHAR 20000u  /* nilai ini yang TERUJI aman di hardware
                                        (uart_probe5.c) -- jauh lebih besar dari
                                        1 periode baud @ 115200 (~86.8us) yang
                                        sebenarnya dibutuhkan, belum dikecilkan/
                                        dikalibrasi presisi krn belum perlu */
static inline void uart_puts(const char *s){
    char buf[UART_BUF_MAX];
    unsigned n = 0;
    while (n < UART_BUF_MAX - 1u && s[n]) { buf[n] = s[n]; n++; }
    for (unsigned i = 0; i < n; i++) {
        UART_TXD = (unsigned)(unsigned char)buf[i];
        delay(UART_DELAY_PER_CHAR);
    }
}

#endif /* MRISCV_H */