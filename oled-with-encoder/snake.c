/* snake.c -- game Snake di OLED SSD1306 128x64 via I2C bit-bang.
 *   Grid: 32x16 sel, tiap sel = 4x4 piksel.
 *   Kontrol: encoder CW = belok kanan, CCW = belok kiri (relatif arah sekarang).
 *   Makan makanan (*) -> ular memanjang + skor naik.
 *   Tabrak dinding / diri -> Game Over, tampil skor, putar encoder = restart.
 *
 *   RAM: circular buffer posisi MAX_LEN=128 (128*2=256 byte), grid 32*16=512 byte,
 *        total data ~800 byte + kode ~1.5KB. Muat di BRAM 4KB.
 */
#include "mriscv.h"

/* ===================== I2C bit-bang ===================== */
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

/* ===================== SSD1306 primitif ===================== */
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

/* gambar/hapus sel 4x4 piksel di posisi grid (gx,gy) */
/* SSD1306 horizontal mode: page=y*4/8, col=gx*4 */
static void draw_cell(int gx, int gy, int on){
    /* sel 4x4 menempati 4 kolom, dan mungkin 1 atau 2 page */
    int px = gx * 4;       /* kolom piksel kiri */
    int py = gy * 4;       /* baris piksel atas */
    int page = py / 8;     /* page utama */
    int bit_offset = py % 8;  /* offset bit dalam page */

    /* 4 piksel vertikal dalam 1 page: bitmask geser */
    unsigned mask = 0x0F << bit_offset;  /* 4 bit menyala */

    cmd(0x21); cmd((unsigned)px); cmd((unsigned)(px+3));
    cmd(0x22); cmd((unsigned)page); cmd((unsigned)page);
    i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
    for(int i=0;i<4;i++) i2c_tx(on ? (unsigned)(mask & 0xFF) : 0x00);
    i2c_stop();

    /* bila sel melintas 2 page (bit_offset > 4) */
    if(bit_offset > 4){
        unsigned mask2 = 0x0F >> (8 - bit_offset);
        cmd(0x21); cmd((unsigned)px); cmd((unsigned)(px+3));
        cmd(0x22); cmd((unsigned)(page+1)); cmd((unsigned)(page+1));
        i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
        for(int i=0;i<4;i++) i2c_tx(on ? (unsigned)(mask2 & 0xFF) : 0x00);
        i2c_stop();
    }
}

/* ===================== font digit 8x8 ===================== */
static const unsigned char font8x8[10][8] = {
  {0x3E,0x51,0x49,0x45,0x3E,0,0,0},{0x00,0x42,0x7F,0x40,0x00,0,0,0},
  {0x42,0x61,0x51,0x49,0x46,0,0,0},{0x21,0x41,0x45,0x4B,0x31,0,0,0},
  {0x18,0x14,0x12,0x7F,0x10,0,0,0},{0x27,0x45,0x45,0x45,0x39,0,0,0},
  {0x3C,0x4A,0x49,0x49,0x30,0,0,0},{0x01,0x71,0x09,0x05,0x03,0,0,0},
  {0x36,0x49,0x49,0x49,0x36,0,0,0},{0x06,0x49,0x49,0x29,0x1E,0,0,0},
};
static void draw_digit(int page, int col, int d, int on){
    cmd(0x21);cmd((unsigned)col);cmd((unsigned)(col+7));
    cmd(0x22);cmd((unsigned)page);cmd((unsigned)page);
    i2c_start();i2c_tx(I2C_ADDR);i2c_tx(CTL_DATA);
    for(int i=0;i<8;i++) i2c_tx(on ? font8x8[d<0?0:d>9?9:d][i] : 0x00);
    i2c_stop();
}
static void draw_score(int sc, int on){
    int tens=0, ones=sc;
    while(ones>=10){ones-=10;tens++;}
    if(tens>9) tens=9;
    draw_digit(7, 56, tens, on);   /* baris bawah, tengah */
    draw_digit(7, 65, ones, on);
}

/* ===================== dimensi grid ===================== */
#define GW      32
#define GH      16
#define MAX_LEN 128   /* max panjang ular (circular buffer) */

/* arah: 0=N 1=E 2=S 3=W */
static const signed char DX[]={ 0,1, 0,-1};
static const signed char DY[]={-1,0, 1, 0};

/* ===================== state game ===================== */
static unsigned char bx[MAX_LEN], by[MAX_LEN];  /* circular buffer posisi */
static unsigned char grid[GH][GW];              /* 0=kosong 1=ular 2=makanan */

static int head_i, tail_i, len_i, dir_i, score_i;
static unsigned char food_x, food_y;

static void place_food(void){
    unsigned char x=food_x, y=food_y;
    for(int i=0;i<GW*GH;i++){
        x++; if(x>=GW){x=0;y++;if(y>=GH)y=0;}
        if(!grid[y][x]){ food_x=x; food_y=y; grid[y][x]=2; draw_cell(x,y,1); return; }
    }
}

static void game_init(void){
    for(int r=0;r<GH;r++) for(int c=0;c<GW;c++) grid[r][c]=0;
    /* ular awal panjang 3, di tengah, arah E */
    for(int i=0;i<3;i++){
        bx[i]=(unsigned char)(GW/2-1+i);
        by[i]=(unsigned char)(GH/2);
        grid[GH/2][GW/2-1+i]=1;
    }
    head_i=2; tail_i=0; len_i=3; dir_i=1; score_i=0;
    food_x=0; food_y=0;
}

/* ===================== encoder ===================== */
#define ENC_CLK 0
#define ENC_DT  1
static unsigned last_clk_s=0;

/* return +1=CW, -1=CCW, 0=diam */
static int enc_poll(void){
    unsigned clk=gpio_rd(ENC_CLK);
    int ret=0;
    if(last_clk_s==1u && clk==0u)
        ret = gpio_rd(ENC_DT) ? 1 : -1;
    last_clk_s=clk;
    return ret;
}

/* ===================== MAIN ===================== */
int main(void){
    sda(1); scl(1);
    ssd1306_init();
    clear();
    last_clk_s = gpio_rd(ENC_CLK);

restart:
    clear();
    game_init();

    /* gambar ular awal */
    for(int i=0;i<3;i++) draw_cell(bx[i],by[i],1);
    place_food();
    draw_score(0,1);

    /* tick counter: gerak ular setiap TICK_MAX poll encoder */
#define TICK_MAX 80
    int tick=0;
    int pending_dir=dir_i;   /* arah berikutnya (diset saat encoder berputar) */

    for(;;){
        /* --- baca encoder -> set arah berikutnya --- */
        int enc=enc_poll();
        if(enc==1)       pending_dir=(dir_i+1)%4;   /* CW  = kanan */
        else if(enc==-1) pending_dir=(dir_i+3)%4;   /* CCW = kiri  */

        /* --- gerak ular setiap TICK_MAX iterasi --- */
        tick++;
        if(tick < TICK_MAX) continue;
        tick=0;

        dir_i=pending_dir;
        int nx=(int)bx[head_i]+DX[dir_i];
        int ny=(int)by[head_i]+DY[dir_i];

        /* tabrakan dinding */
        if(nx<0||nx>=GW||ny<0||ny>=GH) goto game_over;
        /* tabrakan diri */
        if(grid[ny][nx]==1) goto game_over;

        int ate=(grid[ny][nx]==2);
        grid[ny][nx]=1;
        head_i=(head_i+1)%MAX_LEN;
        bx[head_i]=(unsigned char)nx;
        by[head_i]=(unsigned char)ny;
        draw_cell(nx,ny,1);

        if(!ate){
            /* hapus ekor */
            draw_cell(bx[tail_i],by[tail_i],0);
            grid[by[tail_i]][bx[tail_i]]=0;
            tail_i=(tail_i+1)%MAX_LEN;
        } else {
            draw_score(score_i,0);
            score_i++;
            draw_score(score_i,1);
            place_food();
        }
        continue;

game_over:
        /* tampilkan skor, tunggu encoder diputar, lalu restart */
        clear();
        draw_score(score_i,1);
        {
            
            /* tunggu perubahan encoder */
            for(;;){
                int e=enc_poll();
                if(e!=0) break;
                /* busy wait */
            }
        }
        goto restart;
    }
}