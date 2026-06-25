/* oled_test.c -- TAHAP 1: init SSD1306 128x64 + isi seluruh layar ON (putih).
 *   Bukti I2C + init + tulis-data bekerja: seluruh OLED menyala.
 *   I2C bit-bang via GPIO open-drain: datanw[0]=SCL, datanw[1]=SDA.
 */
#include "mriscv.h"
#define SCL 0
#define SDA 1
#define I2C_ADDR  0x78          /* 0x3C << 1 (write) */
#define CTL_CMD   0x00
#define CTL_DATA  0x40

static inline void scl(unsigned v){ gpio_pin(SCL, v); }
static inline void sda(unsigned v){ gpio_pin(SDA, v); }
static inline void ihold(void){ volatile int i; for(i=0;i<4;i++); }  /* jeda kecil */

static void i2c_start(void){ sda(1); scl(1); ihold(); sda(0); ihold(); scl(0); ihold(); }
static void i2c_stop(void){  sda(0); scl(1); ihold(); sda(1); ihold(); }
static void i2c_tx(unsigned b){
    for(int i=0;i<8;i++){ sda((b>>7)&1); b<<=1; scl(1); ihold(); scl(0); ihold(); }
    sda(1); scl(1); ihold(); scl(0); ihold();          /* clock ACK (diabaikan) */
}

/* kirim 1 perintah / 1 data byte */
static void cmd(unsigned c){ i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_CMD); i2c_tx(c); i2c_stop(); }

static void ssd1306_init(void){
    cmd(0xAE);                 /* display off */
    cmd(0xD5); cmd(0x80);      /* clock divide */
    cmd(0xA8); cmd(0x3F);      /* multiplex = 64 */
    cmd(0xD3); cmd(0x00);      /* display offset 0 */
    cmd(0x40);                 /* start line 0 */
    cmd(0x8D); cmd(0x14);      /* charge pump ON */
    cmd(0x20); cmd(0x00);      /* addressing mode: horizontal */
    cmd(0xA1);                 /* segment remap */
    cmd(0xC8);                 /* COM scan direction: remapped */
    cmd(0xDA); cmd(0x12);      /* COM pins */
    cmd(0x81); cmd(0xCF);      /* contrast */
    cmd(0xD9); cmd(0xF1);      /* pre-charge */
    cmd(0xDB); cmd(0x40);      /* VCOMH */
    cmd(0xA4);                 /* resume to RAM content */
    cmd(0xA6);                 /* normal (non-inverted) */
    cmd(0xAF);                 /* display ON */
}

/* isi seluruh GDDRAM dgn pola (0xFF=semua piksel ON, 0x00=off) */
static void fill(unsigned pat){
    cmd(0x21); cmd(0); cmd(127);    /* kolom 0..127 */
    cmd(0x22); cmd(0); cmd(7);      /* halaman 0..7 */
    i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
    for (int i = 0; i < 1024; i++) i2c_tx(pat);   /* 128*64/8 = 1024 byte */
    i2c_stop();
}

int main(void){
    /* idle I2C high dulu */
    sda(1); scl(1);
    ssd1306_init();
    fill(0xFF);                 /* seluruh layar menyala */
    for(;;){}
}