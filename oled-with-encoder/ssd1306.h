/* ============================================================================
 * SSD1306.h -- Library SSD1306 bergaya Adafruit_GFX/Adafruit_SSD1306,
 *   MODE DIRECT-DRAW (tanpa framebuffer di RAM).
 *
 *   API meniru pola Adafruit_GFX: drawPixel(), drawRect(), fillRect(),
 *   setCursor(), print(), clearDisplay() -- TAPI setiap drawPixel() langsung
 *   menulis ke GDDRAM SSD1306 lewat I2C (tidak disimpan di RAM lokal dulu).
 *
 *   PENGGUNAAN: cocok untuk program dengan RAM ketat (mis. game dgn state
 *   besar seperti grid Snake), karena TIDAK memakai 1024 byte framebuffer.
 *
 *   KETERBATASAN dibanding Adafruit_GFX asli:
 *   - Tidak ada batching/optimisasi multi-pixel sebelum kirim ke layar
 *     (Adafruit asli menumpuk semua gambar di buffer, baru kirim sekali
 *      lewat display()). Di sini display() adalah NO-OP karena setiap
 *      gambar sudah langsung tampil saat dipanggil.
 *   - Operasi gambar overlap (drawPixel di posisi yg sama berkali-kali)
 *     akan menyebabkan I2C traffic berulang, lebih lambat dibanding
 *     batched framebuffer untuk gambar kompleks.
 * ============================================================================ */
#ifndef SSD1306_DIRECT_H
#define SSD1306_DIRECT_H
#include "mriscv.h"
#include "font5x7_data.h"

#define SSD1306_WIDTH   128
#define SSD1306_HEIGHT  64

/* ---- I2C bit-bang (lapisan platform, pengganti Wire.h Arduino) ---- */
#define SSD1306_SCL_PIN  0
#define SSD1306_SDA_PIN  1
#define SSD1306_ADDR     0x78
#define SSD1306_CTL_CMD  0x00
#define SSD1306_CTL_DATA 0x40

static inline void ssd1306__ihold(void){ volatile int i; for(i=0;i<4;i++); }
static inline void ssd1306__scl(unsigned v){ gpio_pin(SSD1306_SCL_PIN,v); }
static inline void ssd1306__sda(unsigned v){ gpio_pin(SSD1306_SDA_PIN,v); }
static inline void ssd1306__start(void){
    ssd1306__sda(1); ssd1306__scl(1); ssd1306__ihold();
    ssd1306__sda(0); ssd1306__ihold(); ssd1306__scl(0); ssd1306__ihold();
}
static inline void ssd1306__stop(void){
    ssd1306__sda(0); ssd1306__scl(1); ssd1306__ihold();
    ssd1306__sda(1); ssd1306__ihold();
}
static inline void ssd1306__tx(unsigned b){
    for(int i=0;i<8;i++){
        ssd1306__sda((b>>7)&1); b<<=1;
        ssd1306__scl(1); ssd1306__ihold();
        ssd1306__scl(0); ssd1306__ihold();
    }
    ssd1306__sda(1); ssd1306__scl(1); ssd1306__ihold();
    ssd1306__scl(0); ssd1306__ihold();
}
static inline void ssd1306__cmd(unsigned c){
    ssd1306__start();
    ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_CMD); ssd1306__tx(c);
    ssd1306__stop();
}

/* ---- state cursor (gaya Adafruit_GFX) ---- */
static int ssd1306__cx = 0, ssd1306__cy = 0;
static int ssd1306__color = 1;

/* ================= API gaya Adafruit_SSD1306/GFX ================= */

/* begin(): inisialisasi controller -- setara Adafruit_SSD1306::begin() */
static inline void ssd1306_begin(void){
    ssd1306__sda(1); ssd1306__scl(1);
    ssd1306__cmd(0xAE);ssd1306__cmd(0xD5);ssd1306__cmd(0x80);
    ssd1306__cmd(0xA8);ssd1306__cmd(0x3F);ssd1306__cmd(0xD3);ssd1306__cmd(0x00);
    ssd1306__cmd(0x40);ssd1306__cmd(0x8D);ssd1306__cmd(0x14);
    ssd1306__cmd(0x20);ssd1306__cmd(0x00);
    ssd1306__cmd(0xA1);ssd1306__cmd(0xC8);
    ssd1306__cmd(0xDA);ssd1306__cmd(0x12);ssd1306__cmd(0x81);ssd1306__cmd(0xCF);
    ssd1306__cmd(0xD9);ssd1306__cmd(0xF1);ssd1306__cmd(0xDB);ssd1306__cmd(0x40);
    ssd1306__cmd(0xA4);ssd1306__cmd(0xA6);ssd1306__cmd(0xAF);
}

/* clearDisplay(): hapus seluruh layar -- setara Adafruit_GFX::clearDisplay() */
static inline void ssd1306_clearDisplay(void){
    ssd1306__cmd(0x21);ssd1306__cmd(0);ssd1306__cmd(127);
    ssd1306__cmd(0x22);ssd1306__cmd(0);ssd1306__cmd(7);
    ssd1306__start();
    ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
    for(int i=0;i<1024;i++) ssd1306__tx(0x00);
    ssd1306__stop();
}

/* display(): NO-OP di mode direct-draw (gambar sudah langsung tampil).
   Tetap disediakan agar API kompatibel dengan pola Adafruit_GFX. */
static inline void ssd1306_display(void){ /* intentionally empty */ }

/* fillRect(): isi/hapus blok piksel -- setara Adafruit_GFX::fillRect() */
static inline void ssd1306_fillRect(int x, int y, int w, int h, int color){
    int pg0 = y/8, pg1 = (y+h-1)/8;
    unsigned pat = color ? 0xFF : 0x00;
    for(int p=pg0; p<=pg1 && p<8; p++){
        ssd1306__cmd(0x21); ssd1306__cmd((unsigned)x); ssd1306__cmd((unsigned)(x+w-1));
        ssd1306__cmd(0x22); ssd1306__cmd((unsigned)p); ssd1306__cmd((unsigned)p);
        ssd1306__start(); ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
        for(int i=0;i<w;i++) ssd1306__tx(pat);
        ssd1306__stop();
    }
}

/* drawPixel(): satu titik -- setara Adafruit_GFX::drawPixel().
   CATATAN: di hardware SSD1306, menulis 1 piksel tetap perlu kirim 1 byte
   (1 kolom penuh 8 piksel vertikal), jadi piksel lain di kolom yang sama
   bisa ikut berubah kalau tidak ditangani hati-hati -- di mode direct-draw
   ini, kita lakukan write 1x1 sederhana (cocok utk game grid blocky). */
static inline void ssd1306_drawPixel(int x, int y, int color){
    ssd1306_fillRect(x, y, 1, 1, color);
}

/* setCursor(): set posisi teks -- setara Adafruit_GFX::setCursor() */
static inline void ssd1306_setCursor(int x, int y){ ssd1306__cx=x; ssd1306__cy=y; }

/* setTextColor(): -- setara Adafruit_GFX::setTextColor() */
static inline void ssd1306_setTextColor(int color){ ssd1306__color=color; }

/* drawChar(): satu karakter font 5x7 -- setara Adafruit_GFX::drawChar() */
static inline void ssd1306_drawChar(int x, int page, char c){
    const unsigned char *g;
    if (c < FONT5x7_FIRST || c >= FONT5x7_FIRST + FONT5x7_COUNT) c = ' ';
    g = font5x7[(unsigned char)c - FONT5x7_FIRST];
    ssd1306__cmd(0x21); ssd1306__cmd((unsigned)x); ssd1306__cmd((unsigned)(x+5));
    ssd1306__cmd(0x22); ssd1306__cmd((unsigned)page); ssd1306__cmd((unsigned)page);
    ssd1306__start(); ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
    for(int i=0;i<5;i++) ssd1306__tx(ssd1306__color ? g[i] : 0x00);
    ssd1306__tx(0x00);   /* 1 kolom spasi antar-karakter */
    ssd1306__stop();
}

/* print(): cetak string mulai dari cursor -- setara Adafruit_GFX::print() */
static inline void ssd1306_print(const char *s){
    int x = ssd1306__cx;
    int page = ssd1306__cy / 8;
    while(*s){
        ssd1306_drawChar(x, page, *s);
        x += 6;     /* 5 piksel glyph + 1 spasi */
        s++;
    }
    ssd1306__cx = x;
}

#endif /* SSD1306_H */