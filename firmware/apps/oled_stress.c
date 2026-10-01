/* oled_stress.c -- uji stres OLED SSD1306 + core + bus AXI (top tunggal, GPIO bank 2).
 *
 * Mode BUFFER: tiap frame digambar ke framebuffer RAM (1 KB) lalu dikirim penuh
 * lewat I2C bit-bang (~10 ribu bit per frame = puluhan ribu transaksi GPIO AXI).
 * Satu RONDE = 4 fase, diulang tanpa henti:
 *   A  isi penuh putih lalu hitam (pola paling sederhana; layar kedip penuh)
 *   B  bingkai + batang vertikal bergeser (16 frame; bit slip I2C = bingkai/batang
 *      patah atau bergeser)
 *   C  papan catur 4x4 piksel, polanya dibalik tiap ronde
 *   D  layar teks: nomor ronde, jumlah frame, jumlah error (hex)
 *
 * Pemeriksaan mandiri (sisi CPU/RAM; OLED sendiri write-only, ACK tidak dibaca):
 *   - tiap frame framebuffer di-checksum 2 cara berbeda, masing-masing 2x;
 *     hasil harus sama (deteksi bit-flip RAM/CPU di bawah beban)
 *   - fase A: checksum harus persis 1024*0xFF (putih) / 0 (hitam)
 *   - core trap -> LED LD15 nyala (lihat basys3_top.v)
 * Pengamatan manual: layar tidak boleh glitch/geser/berhenti. LED[7:0] = nomor ronde.
 *
 * UART 115200 (screen /dev/ttyUSB1 115200), 1 baris per ronde:
 *   "R=0003 F=0045 E=0000\r\n"   (ronde, total frame, total error; hex)
 * E harus tetap 0000. Build: make prog FW=oled_stress (dari root; ssd1306.h dicari lewat -Ioled-with-encoder).
 * Simulasi cepat (sedikit frame): tambah -DQUICK ke CFLAGS.
 */
#define SSD1306_USE_BUFFER
#include "ssd1306.h"

#ifdef QUICK
#define SWEEP_FRAMES 1
#else
#define SWEEP_FRAMES 16
#endif

static unsigned frames = 0, errors = 0;

static void hex(char *d, unsigned v, int n){
    for (int i = n - 1; i >= 0; i--) { d[i] = "0123456789ABCDEF"[v & 15u]; v >>= 4; }
    d[n] = 0;
}

/* dua checksum berbeda urutan/operasi */
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

/* periksa konsistensi buffer, lalu kirim ke layar. expect_a < 0 = tak dicek */
static void show(long expect_a){
    unsigned a1 = sum_a(), b1 = sum_b(), a2 = sum_a(), b2 = sum_b();
    if (a1 != a2 || b1 != b2) errors++;
    if (expect_a >= 0 && a1 != (unsigned)expect_a) errors++;
    ssd1306_display();
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
    char h[5];
    uart_puts("R="); hex(h, r, 4); uart_puts(h);
    uart_puts(" F="); hex(h, frames, 4); uart_puts(h);
    uart_puts(" E="); hex(h, errors, 4); uart_puts(h);
    uart_puts("\r\n");
}

int main(void){
    unsigned r = 0;
    ssd1306_begin();

    for (;;) {
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
        ssd1306_setCursor(8, 8);  ssd1306_print("OLED STRESS");
        put_line("RND ", r, 24);
        put_line("FRM ", frames, 36);
        put_line("ERR ", errors, 48);
        show(-1);

        r++;
        led_set(r);
        uart_report(r);
    }
}
