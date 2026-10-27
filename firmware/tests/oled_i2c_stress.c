/* oled_i2c_stress.c -- uji stres controller I2C master hardware lewat OLED SSD1306.
 *
 * Beda dengan oled_stress.c (bit-bang, ACK tidak dibaca): di sini ACK tiap byte
 * DIBACA oleh hardware, jadi error bus terdeteksi mandiri.
 * Satu RONDE, diulang tanpa henti, kecepatan SCL berputar tiap ronde:
 *   DIV 31 (~400 kHz) -> 62 (~200 kHz) -> 125 (~100 kHz) -> 31 ...
 *   A  putih penuh lalu hitam penuh (1 frame = ~1,3 ribu byte beruntun)
 *   B  bingkai + batang vertikal bergeser (16 frame)
 *   C  papan catur 4x4, dibalik tiap ronde
 *   D  layar teks status
 *   E  "hammer": 512 transaksi pendek (START+3 byte+STOP) ganti kontras 0x81,v
 *      -> banyak START/STOP berurutan, layar berkedip terang-gelap lalu normal
 * Pemeriksaan mandiri:
 *   - N: jumlah byte tanpa ACK (NACK) dan arbitrasi hilang  -> harus 0
 *   - S: checksum framebuffer tak konsisten (RAM/CPU)       -> harus 0
 *   - T: waktu frame (rdcycle) di luar jendela teoretis     -> harus 0
 *        (terlalu cepat = bit/byte hilang, terlalu lambat = engine macet/stretch)
 *   - core trap -> LD15 nyala. LED[7:0] = nomor ronde.
 * UART 115200, 1 baris per ronde (hex):
 *   "R=0003 DIV=007D F=0045 N=0000 A=0000 S=0000 T=0000 C=0012A4F0\r\n"
 *   (C = siklus frame terakhir). N, A, S, T harus tetap 0000.
 * Build: make prog FW=oled_i2c_stress. Simulasi cepat: -DQUICK (DIV kecil, 1 frame sweep).
 */
#define SSD1306_HW_I2C
#define SSD1306_USE_BUFFER
#include "ssd1306.h"

#ifdef QUICK
#define SWEEP_FRAMES 1
#define HAMMER_N     16
static const unsigned div_tab[4] = { 8, 12, 16, 8 };
#else
#define SWEEP_FRAMES 16
#define HAMMER_N     512
static const unsigned div_tab[4] = { 31, 62, 125, 31 };
#endif

static unsigned frames = 0, sum_err = 0, time_err = 0, last_cyc = 0;
static unsigned cur_div;

static void hex(char *d, unsigned v, int n){
    for (int i = n - 1; i >= 0; i--) { d[i] = "0123456789ABCDEF"[v & 15u]; v >>= 4; }
    d[n] = 0;
}

static unsigned sum_a(void){
    unsigned s = 0;
    for (int i = 0; i < SSD1306_BUFSIZE; i++) s += ssd1306_buf[i];
    return s;
}
static unsigned sum_b(void){
    unsigned s = 0x1234u;
    for (int i = SSD1306_BUFSIZE - 1; i >= 0; i--)
        s = ((s << 1) | (s >> 31)) ^ ssd1306_buf[i];
    return s;
}

/* Jendela waktu display(): 6 perintah x 3 byte + 1027 byte data = 1045 byte,
 * tiap byte 9 clock SCL = 36 fase x DIV siklus (1045*36 = 37620 siklus per DIV).
 * Firmware menunggu engine selesai per byte (tulis DATA, tulis CMD, polling STATUS),
 * jadi tiap byte kena overhead CPU serial ~300 siklus (terukur di simulasi: 604k
 * siklus @DIV=8 vs ideal 301k). Batas bawah 15/16 ideal (lebih cepat = mustahil,
 * ada yang hilang); batas atas ideal + 512 siklus/byte (lebih lambat = engine
 * macet / stretch). Tanpa operator * dan / (lihat CLAUDE.md). */
static void check_time(unsigned cyc){
    unsigned ideal = 0;
    for (unsigned i = 0; i < cur_div; i++) { ideal += 37620u; __asm__ volatile("" : "+r"(ideal)); }  /* cegah GCC ubah loop jadi mul */
    if (cyc < ideal - (ideal >> 4) || cyc > ideal + (1045u << 9)) time_err++;
}

/* periksa konsistensi buffer, lalu kirim ke layar. expect_a < 0 = tak dicek */
static void show(long expect_a){
    unsigned a1 = sum_a(), b1 = sum_b(), a2 = sum_a(), b2 = sum_b();
    if (a1 != a2 || b1 != b2) sum_err++;
    if (expect_a >= 0 && a1 != (unsigned)expect_a) sum_err++;
    unsigned t0 = rdcycle();
    ssd1306_display();
    last_cyc = rdcycle() - t0;
    check_time(last_cyc);
    frames++;
}

static void fill(unsigned char v){
    for (int i = 0; i < SSD1306_BUFSIZE; i++) ssd1306_buf[i] = v;
}

static void border(void){
    ssd1306_fillRect(0, 0, SSD1306_WIDTH, 1, 1);
    ssd1306_fillRect(0, SSD1306_HEIGHT - 1, SSD1306_WIDTH, 1, 1);
    ssd1306_fillRect(0, 0, 1, SSD1306_HEIGHT, 1);
    ssd1306_fillRect(SSD1306_WIDTH - 1, 0, 1, SSD1306_HEIGHT, 1);
}

static void put_line(const char *label, unsigned v, int y){
    char h[5];
    hex(h, v, 4);
    ssd1306_setCursor(8, y);
    ssd1306_print(label);
    ssd1306_print(h);
}

static void uart_report(unsigned r){
    char h[9];
    uart_puts("R=");    hex(h, r, 4);          uart_puts(h);
    uart_puts(" DIV="); hex(h, cur_div, 4);    uart_puts(h);
    uart_puts(" F=");   hex(h, frames, 4);     uart_puts(h);
    uart_puts(" N=");   hex(h, ssd1306__nacks, 4); uart_puts(h);
    uart_puts(" A=");   hex(h, ssd1306__arbs, 4);  uart_puts(h);
    uart_puts(" S=");   hex(h, sum_err, 4);    uart_puts(h);
    uart_puts(" T=");   hex(h, time_err, 4);   uart_puts(h);
    uart_puts(" C=");   hex(h, last_cyc, 8);   uart_puts(h);
    uart_puts("\r\n");
}

int main(void){
    unsigned r = 0;
    ssd1306_begin();                           /* i2c_hw_init + init SSD1306 */

    for (;;) {
        cur_div = div_tab[r & 3u];
        I2C_DIV = cur_div;                     /* engine idle di sini */

        /* A: putih penuh, hitam penuh */
        fill(0xFF); show(SSD1306_BUFSIZE * 255L);
        fill(0x00); show(0);

        /* B: bingkai + batang vertikal bergeser */
        int bx = 4;
        for (int k = 0; k < SWEEP_FRAMES; k++) {
            ssd1306_clearDisplay();
            border();
            ssd1306_fillRect(bx, 2, 4, SSD1306_HEIGHT - 4, 1);
            show(-1);
            bx += 7;
        }

        /* C: papan catur 4x4 piksel, dibalik tiap ronde */
        ssd1306_clearDisplay();
        unsigned inv = r & 1u;
        for (int y = 0; y < SSD1306_HEIGHT; y++)
            for (int x = 0; x < SSD1306_WIDTH; x++)
                ssd1306_drawPixel(x, y, (((x >> 2) ^ (y >> 2)) & 1u) ^ inv);
        show(-1);

        /* D: layar teks status */
        ssd1306_clearDisplay();
        border();
        ssd1306_setCursor(8, 8);  ssd1306_print("I2C HW STRESS");
        put_line("RND ", r, 24);
        put_line("NAK ", ssd1306__nacks, 36);
        put_line("ERR ", sum_err + time_err + ssd1306__arbs, 48);
        show(-1);

        /* E: hammer -- transaksi pendek berurutan (kontras naik-turun) */
        for (int k = 0; k < HAMMER_N; k++)
            ssd1306__cmd(0x81), ssd1306__cmd(k & 1 ? 0x01 : 0xFF);
        ssd1306__cmd(0x81); ssd1306__cmd(0xCF);   /* kembalikan kontras normal */

        r++;
        led_set(r);
        uart_report(r);
    }
}
