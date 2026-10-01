/* encoder_demo.c -- Demo rotary encoder + ssd1306.h (mode-agnostic).
 *
 *   Bekerja di MODE DIRECT maupun MODE BUFFER tanpa ubah kode:
 *   - Cukup selalu panggil ssd1306_display() setelah menggambar.
 *     Di direct: no-op. Di buffer: mendorong buffer ke layar.
 *
 *   Untuk pilih mode, di ATAS file ini (sebelum #include):
 *     #define SSD1306_USE_BUFFER    // <- aktifkan utk mode buffer
 *
 *   pindata[0]=CLK, pindata[1]=DT (encoder). datanw[0]=SCL, datanw[1]=SDA (OLED).
 */

/* ==== GANTI MODE DI SINI: uncomment baris di bawah utk mode buffer ==== */
#define SSD1306_USE_BUFFER

#include "ssd1306.h"

#define ENC_CLK  0
#define ENC_DT   1
#define CNT_MIN  (-99)
#define CNT_MAX   99

static void int_to_str(int v, char *buf){
    char tmp[8]; int i=0, neg=0, j=0;
    if(v==0){ buf[0]='0'; buf[1]=0; return; }
    if(v<0){ neg=1; v=-v; }
    while(v>0){ int q=0,r=v; while(r>=10){r-=10;q++;} tmp[i++]=(char)('0'+r); v=q; }
    if(neg) buf[j++]='-';
    while(i-->0) buf[j++]=tmp[i];
    buf[j]=0;
}
static int str_len(const char *s){ int n=0; while(*s++) n++; return n; }
static int val_to_bar(int v){
    int x=v+99, bar=0;
    while(x>=2){ x-=2; bar++; }
    if(bar>100) bar=100;
    return bar;
}

static void draw_value(int val, int old_val){
    char buf[8];
    /* hapus teks lama */
    int_to_str(old_val, buf);
    int old_w = str_len(buf)*6, old_x = 64 - old_w/2;
    ssd1306_fillRect(old_x-2, 24, old_w+4, 8, 0);
    /* teks baru terpusat */
    int_to_str(val, buf);
    int w = str_len(buf)*6, x = 64 - w/2;
    ssd1306_setCursor(x, 24);
    ssd1306_print(buf);
    /* bar */
    ssd1306_fillRect(14, 41, 100, 4, 0);
    int bar = val_to_bar(val);
    if(bar>0) ssd1306_fillRect(14, 41, bar, 4, 1);
    ssd1306_fillRect(63, 39, 2, 8, 1);
}

int main(void){
    ssd1306_begin();
    ssd1306_clearDisplay();

    /* layout statis */
    ssd1306_setCursor(46, 0);   ssd1306_print("ENC:");
    ssd1306_fillRect(13, 39, 1, 8, 1);
    ssd1306_fillRect(114, 39, 1, 8, 1);
    ssd1306_setCursor(0,  48);  ssd1306_print("-99");
    ssd1306_setCursor(106,48);  ssd1306_print("99");
    ssd1306_setCursor(16, 56);  ssd1306_print("CW:+  CCW:-");

    int count = 0, shown = 1;
    draw_value(0, 0);
    shown = 0;
    ssd1306_display();          /* push awal (no-op di direct) */

    unsigned last_clk = gpio2_rd(ENC_CLK);
    for(;;){
        unsigned clk = gpio2_rd(ENC_CLK);
        if(last_clk==1u && clk==0u){
            if(gpio2_rd(ENC_DT)) count++; else count--;
            if(count>CNT_MAX) count=CNT_MAX;
            if(count<CNT_MIN) count=CNT_MIN;
        }
        last_clk = clk;

        if(count != shown){
            draw_value(count, shown);
            ssd1306_display();  /* push perubahan (no-op di direct) */
            shown = count;
        }
    }
}