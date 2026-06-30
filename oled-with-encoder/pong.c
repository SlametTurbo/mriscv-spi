/* pong.c -- Pong 1-player di OLED SSD1306 128x64 via I2C bit-bang.
 *   Slider kiri  : rotary encoder (datanw[0]=SCL, datanw[1]=SDA).
 *   Dinding kanan: bola memantul.
 *   Atas/bawah   : bola memantul.
 *   Miss slider  : game over, tekan encoder tidak ada (putar balik -> restart).
 *
 *   Strategi render: PARTIAL UPDATE -- hanya region bola & slider yg berubah
 *   yang ditulis ulang ke OLED (hapus lama, gambar baru). Ini membuat game
 *   cukup responsif meski I2C bit-bang lambat (~1.5 MHz clock core).
 *
 *   RAM: game state ~30 byte, framebuffer TIDAK disimpan (tulis langsung ke OLED).
 *   Total ukuran program: < 2 KB (muat di BRAM 4 KB).
 */
#include "mriscv.h"

/* ======================== I2C bit-bang ======================== */
#define SCL_PIN  0
#define SDA_PIN  1
#define I2C_ADDR 0x78
#define CTL_CMD  0x00
#define CTL_DATA 0x40

static void ihold(void){ volatile int i; for(i=0;i<4;i++); }
static void scl(unsigned v){ gpio_pin(SCL_PIN,v); }
static void sda(unsigned v){ gpio_pin(SDA_PIN,v); }
static void i2c_start(void){ sda(1);scl(1);ihold();sda(0);ihold();scl(0);ihold(); }
static void i2c_stop(void){ sda(0);scl(1);ihold();sda(1);ihold(); }
static void i2c_tx(unsigned b){
    for(int i=0;i<8;i++){sda((b>>7)&1);b<<=1;scl(1);ihold();scl(0);ihold();}
    sda(1);scl(1);ihold();scl(0);ihold();
}
static void cmd(unsigned c){i2c_start();i2c_tx(I2C_ADDR);i2c_tx(CTL_CMD);i2c_tx(c);i2c_stop();}

/* ======================== SSD1306 init & primitif ======================== */
static void ssd1306_init(void){
    cmd(0xAE);cmd(0xD5);cmd(0x80);cmd(0xA8);cmd(0x3F);cmd(0xD3);cmd(0x00);
    cmd(0x40);cmd(0x8D);cmd(0x14);cmd(0x20);cmd(0x00);cmd(0xA1);cmd(0xC8);
    cmd(0xDA);cmd(0x12);cmd(0x81);cmd(0xCF);cmd(0xD9);cmd(0xF1);cmd(0xDB);
    cmd(0x40);cmd(0xA4);cmd(0xA6);cmd(0xAF);
}
static void clear(void){
    cmd(0x21);cmd(0);cmd(127);cmd(0x22);cmd(0);cmd(7);
    i2c_start();i2c_tx(I2C_ADDR);i2c_tx(CTL_DATA);
    for(int i=0;i<1024;i++) i2c_tx(0x00);
    i2c_stop();
}

/* tulis blok piksel: set_region lalu kirim data
   page = baris/8 (0..7), col = kolom (0..127)
   data = 1 byte per kolom (8 piksel vertikal)                       */
static void fill_region(int page, int col, int ncols, unsigned pat){
    cmd(0x21); cmd((unsigned)col); cmd((unsigned)(col+ncols-1));
    cmd(0x22); cmd((unsigned)page); cmd((unsigned)page);
    i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
    for(int i=0;i<ncols;i++) i2c_tx(pat);
    i2c_stop();
}

/* gambar/hapus rect: x,y piksel, w,h piksel.
   SSD1306 page-addressed: kita gambar per page yang terdampak.      */
static void draw_rect(int x, int y, int w, int h, int on){
    int pg0 = y/8, pg1 = (y+h-1)/8;
    unsigned pat = on ? 0xFF : 0x00;
    /* untuk page parsial, kita pakai 0xFF/0x00 saja (kotak penuh per page) */
    for(int p=pg0; p<=pg1 && p<8; p++)
        fill_region(p, x, w, pat);
}

/* ======================== font digit 8x8 ======================== */
static const unsigned char font8x8[10][8] = {
  {0x3E,0x51,0x49,0x45,0x3E,0,0,0}, /* 0 */
  {0x00,0x42,0x7F,0x40,0x00,0,0,0}, /* 1 */
  {0x42,0x61,0x51,0x49,0x46,0,0,0}, /* 2 */
  {0x21,0x41,0x45,0x4B,0x31,0,0,0}, /* 3 */
  {0x18,0x14,0x12,0x7F,0x10,0,0,0}, /* 4 */
  {0x27,0x45,0x45,0x45,0x39,0,0,0}, /* 5 */
  {0x3C,0x4A,0x49,0x49,0x30,0,0,0}, /* 6 */
  {0x01,0x71,0x09,0x05,0x03,0,0,0}, /* 7 */
  {0x36,0x49,0x49,0x49,0x36,0,0,0}, /* 8 */
  {0x06,0x49,0x49,0x29,0x1E,0,0,0}, /* 9 */
};
static void draw_digit(int page, int col, int d, int on){
    cmd(0x21);cmd((unsigned)col);cmd((unsigned)(col+7));
    cmd(0x22);cmd((unsigned)page);cmd((unsigned)page);
    i2c_start();i2c_tx(I2C_ADDR);i2c_tx(CTL_DATA);
    for(int i=0;i<8;i++) i2c_tx(on ? font8x8[d][i] : 0x00);
    i2c_stop();
}
static void draw_score(int score, int on){
    /* hindari / dan % (butuh libgcc): hitung manual */
    int tens=0, ones=score;
    while(ones>=10){ones-=10;tens++;}
    if(tens>9) tens=9;              /* cap di 99 */
    draw_digit(0, 56, tens, on);
    draw_digit(0, 65, ones, on);
}

/* ======================== dimensi game ======================== */
#define GW      124     /* lebar area game (0..123) */
#define GH      64      /* tinggi area game */
#define PAD_X   2       /* X tetap slider */
#define PAD_W   3       /* lebar slider */
#define PAD_H   16      /* tinggi slider */
#define BALL_S  3       /* ukuran bola */
#define WALL_X  (GW-1)  /* X dinding kanan */

/* ======================== encoder ======================== */
#define ENC_CLK 0
#define ENC_DT  1
static int enc_count = 0;
static unsigned last_clk = 0;
static void enc_update(void){
    unsigned clk = gpio_rd(ENC_CLK);
    if(last_clk==1u && clk==0u){
        if(gpio_rd(ENC_DT)) enc_count++; else enc_count--;
    }
    last_clk = clk;
}

/* ======================== MAIN ======================== */
int main(void){
    sda(1); scl(1);
    ssd1306_init();
    clear();

    /* gambar dinding kanan (tetap) */
    for(int p=0;p<8;p++) fill_region(p, WALL_X, 1, 0xFF);

restart:;
    /* state game */
    int bx=GW/2, by=GH/2, vx=-1, vy=1;
    int py=GH/2-PAD_H/2;
    int score=0;
    int prev_py=py;

    /* gambar awal */
    draw_rect(PAD_X, py, PAD_W, PAD_H, 1);
    draw_rect(bx, by, BALL_S, BALL_S, 1);
    draw_score(0, 1);

    last_clk = gpio_rd(ENC_CLK);
    enc_count = py;    /* init posisi encoder = posisi slider */

    for(;;){
        /* --- baca encoder & gerak slider --- */
        enc_update();
        int new_py = enc_count;
        if(new_py < 0)       { new_py=0; enc_count=0; }
        if(new_py > GH-PAD_H){ new_py=GH-PAD_H; enc_count=GH-PAD_H; }

        /* hapus slider lama, gambar baru (hanya jika berubah) */
        if(new_py != prev_py){
            draw_rect(PAD_X, prev_py, PAD_W, PAD_H, 0);
            draw_rect(PAD_X, new_py,  PAD_W, PAD_H, 1);
            prev_py = new_py;
        }
        py = new_py;

        /* --- fisika bola (jalan tiap beberapa iterasi encoder) --- */
        /* delay kecil utk seimbangkan kecepatan bola vs responsivitas slider */
        static int tick=0;
        tick++;
        if(tick < 1){ continue; }   /* gerak bola 1x tiap x pembacaan encoder */
        tick=0;

        int nx=bx+vx, ny=by+vy;

        /* pantulan atas/bawah */
        if(ny<=0)          { ny=0;        vy= 1; }
        if(ny+BALL_S>=GH)  { ny=GH-BALL_S; vy=-1; }

        /* pantulan dinding kanan */
        if(nx+BALL_S>=WALL_X){ nx=WALL_X-BALL_S; vx=-1; }

        /* cek slider */
        if(vx<0 && nx<=PAD_X+PAD_W){
            int hit=(ny+BALL_S>py)&&(ny<py+PAD_H);
            if(hit){
                nx=PAD_X+PAD_W; vx=1;
                int rel=(ny+BALL_S/2)-(py+PAD_H/2);
                vy=(rel>4)?1:(rel<-4?-1:vy);
                /* hapus skor lama, tambah, gambar baru */
                draw_score(score,0); score++; draw_score(score,1);
            } else {
                /* GAME OVER */
                clear();
                /* tulis "GAME OVER" sbg pola -- tampilkan skor akhir besar */
                /* gambar skor besar di tengah layar */
                int st=0, so=score;
                while(so>=10){so-=10;st++;}
                if(st>9)st=9;
                draw_digit(2, 44, st, 1);
                draw_digit(2, 53, so, 1);
                /* tunggu encoder diputar untuk restart */
                int old_enc=enc_count;
                for(;;){
                    enc_update();
                    if(enc_count != old_enc) break;
                }
                /* clear & restart */
                clear();
                for(int p=0;p<8;p++) fill_region(p,WALL_X,1,0xFF);
                goto restart;
            }
        }

        /* hapus bola lama, gambar baru */
        if(nx!=bx || ny!=by){
            draw_rect(bx, by, BALL_S, BALL_S, 0);
            draw_rect(nx, ny, BALL_S, BALL_S, 1);
        }
        bx=nx; by=ny;
    }
}