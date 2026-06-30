/* encoder_oled.c -- rotary encoder -> tampilkan nilai (hex) di OLED SSD1306.
 *   I2C bit-bang via GPIO open-drain: datanw[0]=SCL, datanw[1]=SDA.
 *   pindata[0]=enc CLK, pindata[1]=enc DT.
 *   Putar -> nilai naik/turun, ditampilkan sbg 2 digit hex di OLED.
 */



#include "mriscv.h"
#define SCL 0
#define SDA 1
#define ENC_CLK 0
#define ENC_DT  1
#define I2C_ADDR 0x78
#define CTL_CMD  0x00
#define CTL_DATA 0x40

static inline void scl(unsigned v){ gpio_pin(SCL, v); }
static inline void sda(unsigned v){ gpio_pin(SDA, v); }
static inline void ihold(void){ volatile int i; for(i=0;i<4;i++); }

static void i2c_start(void){ sda(1); scl(1); ihold(); sda(0); ihold(); scl(0); ihold(); }
static void i2c_stop(void){  sda(0); scl(1); ihold(); sda(1); ihold(); }
static void i2c_tx(unsigned b){
    for(int i=0;i<8;i++){ sda((b>>7)&1); b<<=1; scl(1); ihold(); scl(0); ihold(); }
    sda(1); scl(1); ihold(); scl(0); ihold();
}
static void cmd(unsigned c){ 
    i2c_start(); 
    i2c_tx(I2C_ADDR); 
    i2c_tx(CTL_CMD); 
    i2c_tx(c); 
    i2c_stop(); }

static void ssd1306_init(void){
    cmd(0xAE); cmd(0xD5); cmd(0x80); cmd(0xA8); cmd(0x3F); cmd(0xD3); cmd(0x00);
    cmd(0x40); cmd(0x8D); cmd(0x14); cmd(0x20); cmd(0x00); cmd(0xA1); cmd(0xC8);
    cmd(0xDA); cmd(0x12); cmd(0x81); cmd(0xCF); cmd(0xD9); cmd(0xF1); cmd(0xDB);
    cmd(0x40); cmd(0xA4); cmd(0xA6); cmd(0xAF);
}

static void clear(void){
    cmd(0x21); cmd(0); cmd(127); cmd(0x22); cmd(0); cmd(7);
    i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
    for(int i=0;i<1024;i++) i2c_tx(0x00);
    i2c_stop();
}

static const unsigned char font8x8[16][8] = {
 {0x3E,0x51,0x49,0x45,0x3E,0,0,0},{0x00,0x42,0x7F,0x40,0x00,0,0,0},
 {0x42,0x61,0x51,0x49,0x46,0,0,0},{0x21,0x41,0x45,0x4B,0x31,0,0,0},
 {0x18,0x14,0x12,0x7F,0x10,0,0,0},{0x27,0x45,0x45,0x45,0x39,0,0,0},
 {0x3C,0x4A,0x49,0x49,0x30,0,0,0},{0x01,0x71,0x09,0x05,0x03,0,0,0},
 {0x36,0x49,0x49,0x49,0x36,0,0,0},{0x06,0x49,0x49,0x29,0x1E,0,0,0},
 {0x7E,0x11,0x11,0x11,0x7E,0,0,0},{0x7F,0x49,0x49,0x49,0x36,0,0,0},
 {0x3E,0x41,0x41,0x41,0x22,0,0,0},{0x7F,0x41,0x41,0x22,0x1C,0,0,0},
 {0x7F,0x49,0x49,0x49,0x41,0,0,0},{0x7F,0x09,0x09,0x09,0x01,0,0,0},
};


static void draw_glyph(unsigned page, unsigned col, const unsigned char *g){
    cmd(0x21); cmd(col); cmd(col+7);
    cmd(0x22); cmd(page); cmd(page);
    i2c_start(); i2c_tx(I2C_ADDR); i2c_tx(CTL_DATA);
    for(int i=0;i<8;i++) i2c_tx(g[i]);
    i2c_stop();
}
static void draw_hex2(unsigned v){
    draw_glyph(3, 52, font8x8[(v>>4)&0xF]);
    draw_glyph(3, 62, font8x8[v & 0xF]);
}

int main(void){
    sda(1); scl(1);
    ssd1306_init();
    clear();

    int count = 0, shown = -1;
    unsigned last_clk = gpio_rd(ENC_CLK);
    draw_hex2(0x00);
    shown = 0;

    for(;;){
        unsigned clk = gpio_rd(ENC_CLK);
        if (last_clk == 1u && clk == 0u){
            if (gpio_rd(ENC_DT)) count++; else count--;
        }
        last_clk = clk;

        if ((count & 0xFF) != (shown & 0xFF)){
            draw_hex2((unsigned)count & 0xFF);
            shown = count;
        }
    }
}