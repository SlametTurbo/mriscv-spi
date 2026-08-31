/* ============================================================================
 * ssd1306.h -- Library SSD1306 bergaya Adafruit_GFX/Adafruit_SSD1306.
 *
 *   DUA MODE dalam satu file, dipilih lewat macro SEBELUM #include:
 *
 *     // MODE DIRECT (default): tiap gambar langsung ke OLED, hemat RAM.
 *     #include "ssd1306.h"
 *
 *     // MODE BUFFER: gambar ke framebuffer RAM (1024 byte), tampil saat
 *     //             ssd1306_display() dipanggil. Anti-flicker, tapi makan RAM.
 *     #define SSD1306_USE_BUFFER
 *     #include "ssd1306.h"
 *
 *   API SAMA di kedua mode (drawPixel, fillRect, drawChar, print, dll),
 *   jadi program tinggal tambah/hapus 1 baris #define untuk ganti mode.
 *
 *   PENTING soal display():
 *     - MODE DIRECT: display() = no-op (gambar sudah tampil saat dipanggil).
 *     - MODE BUFFER: display() WAJIB dipanggil agar isi buffer muncul di layar.
 *   Tulis program dgn selalu memanggil display() setelah menggambar -> aman
 *   di kedua mode (di direct cuma tidak melakukan apa-apa).
 * ============================================================================ */
#ifndef SSD1306_H
#define SSD1306_H
#include "mriscv.h"
#include "font5x7_data.h"

#define SSD1306_WIDTH   128
#define SSD1306_HEIGHT  64

/* ---- konfigurasi I2C (lapisan platform, pengganti Wire.h Arduino) ---- */
#define SSD1306_SCL_PIN  0
#define SSD1306_SDA_PIN  1
#define SSD1306_ADDR     0x78
#define SSD1306_CTL_CMD  0x00
#define SSD1306_CTL_DATA 0x40

/* ================= I2C bit-bang (dipakai kedua mode) ================= */
static inline void ssd1306__ihold(void){ volatile int i; for(i=0;i<16;i++); }  /* x4: clock naik 12.5->50MHz */
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

/* ---- urutan init SSD1306 (sama kedua mode) ---- */
static inline void ssd1306__init_seq(void){
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

/* ---- state cursor & warna (sama kedua mode) ---- */
static int ssd1306__cx = 0, ssd1306__cy = 0;
static int ssd1306__color = 1;
static inline void ssd1306_setCursor(int x, int y){ ssd1306__cx=x; ssd1306__cy=y; }
static inline void ssd1306_setTextColor(int color){ ssd1306__color=color; }


/* ############################################################################
 * ###################        MODE BUFFER          ############################
 * ############################################################################ */
#ifdef SSD1306_USE_BUFFER

#define SSD1306_BUFSIZE (SSD1306_WIDTH * SSD1306_HEIGHT / 8)   /* 1024 byte */
static unsigned char ssd1306_buf[SSD1306_BUFSIZE];

static inline void ssd1306_begin(void){
    ssd1306__init_seq();
    for(int i=0;i<SSD1306_BUFSIZE;i++) ssd1306_buf[i]=0;
}

/* clearDisplay(): hapus BUFFER (belum tampil sampai display()) */
static inline void ssd1306_clearDisplay(void){
    for(int i=0;i<SSD1306_BUFSIZE;i++) ssd1306_buf[i]=0;
}

/* display(): kirim seluruh buffer ke layar fisik -- WAJIB dipanggil */
static inline void ssd1306_display(void){
    ssd1306__cmd(0x21);ssd1306__cmd(0);ssd1306__cmd(127);
    ssd1306__cmd(0x22);ssd1306__cmd(0);ssd1306__cmd(7);
    ssd1306__start();
    ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
    for(int i=0;i<SSD1306_BUFSIZE;i++) ssd1306__tx(ssd1306_buf[i]);
    ssd1306__stop();
}

/* drawPixel(): tulis 1 bit ke buffer (posisi y bebas, bukan per-page) */
static inline void ssd1306_drawPixel(int x, int y, int color){
    if(x<0||x>=SSD1306_WIDTH||y<0||y>=SSD1306_HEIGHT) return;
    int idx = x + (y/8) * SSD1306_WIDTH;
    unsigned char mask = (unsigned char)(1u << (y % 8));
    if(color) ssd1306_buf[idx] |= mask;
    else      ssd1306_buf[idx] &= (unsigned char)~mask;
}

static inline void ssd1306_fillRect(int x, int y, int w, int h, int color){
    for(int j=0;j<h;j++) for(int i=0;i<w;i++) ssd1306_drawPixel(x+i,y+j,color);
}

/* drawChar(): tulis glyph ke buffer pada (x,y) piksel bebas (fleksibel) */
static inline void ssd1306_drawChar(int x, int y, char c){
    const unsigned char *g;
    if(c<FONT5x7_FIRST || c>=FONT5x7_FIRST+FONT5x7_COUNT) c=' ';
    g = font5x7[(unsigned char)c - FONT5x7_FIRST];
    for(int col=0; col<5; col++){
        unsigned char line = g[col];
        for(int row=0; row<7; row++)
            ssd1306_drawPixel(x+col, y+row, ((line>>row)&1) ? ssd1306__color : 0);
    }
}

static inline void ssd1306_print(const char *s){
    int x = ssd1306__cx, y = ssd1306__cy;
    while(*s){ ssd1306_drawChar(x, y, *s); x += 6; s++; }
    ssd1306__cx = x;
}


/* ############################################################################
 * ###################        MODE DIRECT          ############################
 * ############################################################################ */
#else  /* !SSD1306_USE_BUFFER */

static inline void ssd1306_begin(void){ ssd1306__init_seq(); }

static inline void ssd1306_clearDisplay(void){
    ssd1306__cmd(0x21);ssd1306__cmd(0);ssd1306__cmd(127);
    ssd1306__cmd(0x22);ssd1306__cmd(0);ssd1306__cmd(7);
    ssd1306__start();
    ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
    for(int i=0;i<1024;i++) ssd1306__tx(0x00);
    ssd1306__stop();
}

/* display(): NO-OP di mode direct (gambar sudah langsung tampil) */
static inline void ssd1306_display(void){ /* intentionally blank */ }

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

static inline void ssd1306_drawPixel(int x, int y, int color){
    ssd1306_fillRect(x, y, 1, 1, color);
}

/* drawChar(): mode direct pakai 'page' (y/8) -- glyph sejajar page.
   Untuk API seragam, argumen kedua tetap koordinat Y piksel, dikonversi
   ke page di dalam. */
static inline void ssd1306_drawChar(int x, int y, char c){
    const unsigned char *g;
    int page = y / 8;
    if(c<FONT5x7_FIRST || c>=FONT5x7_FIRST+FONT5x7_COUNT) c=' ';
    g = font5x7[(unsigned char)c - FONT5x7_FIRST];
    ssd1306__cmd(0x21); ssd1306__cmd((unsigned)x); ssd1306__cmd((unsigned)(x+5));
    ssd1306__cmd(0x22); ssd1306__cmd((unsigned)page); ssd1306__cmd((unsigned)page);
    ssd1306__start(); ssd1306__tx(SSD1306_ADDR); ssd1306__tx(SSD1306_CTL_DATA);
    for(int i=0;i<5;i++) ssd1306__tx(ssd1306__color ? g[i] : 0x00);
    ssd1306__tx(0x00);
    ssd1306__stop();
}

static inline void ssd1306_print(const char *s){
    int x = ssd1306__cx, y = ssd1306__cy;
    while(*s){ ssd1306_drawChar(x, y, *s); x += 6; s++; }
    ssd1306__cx = x;
}

#endif /* SSD1306_USE_BUFFER */

#endif /* SSD1306_H */