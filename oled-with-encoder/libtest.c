/* libtest.c -- DEMO LENGKAP untuk menguji SSD1306_direct.h.
 *
 *   Menguji semua fungsi utama library secara berurutan, dengan jeda
 *   antar tahap, supaya mudah dilihat fungsi mana yang berhasil:
 *
 *   1. begin() + clearDisplay()  -> layar harus kosong/hitam
 *   2. print() teks              -> tampil "SSD1306 DIRECT"
 *   3. fillRect()                -> kotak putih solid muncul
 *   4. drawPixel() pola garis    -> garis diagonal titik-titik
 *   5. fillRect() hapus (color=0)-> sebagian kotak terhapus
 *
 *   Tidak ada loop cepat -- tiap tahap diberi delay panjang supaya
 *   mudah diamati & difoto utk dokumentasi skripsi.
 */
#include "SSD1306_direct.h"

static void long_delay(unsigned n){
    volatile unsigned i, j;
    for(i=0;i<n;i++) for(j=0;j<2000;j++) __asm__ volatile("");
}

int main(void){
    /* ---- Tahap 1: init + clear ---- */
    ssd1306_begin();
    ssd1306_clearDisplay();
    long_delay(50);

    /* ---- Tahap 2: teks (uji print/setCursor/drawChar) ---- */
    ssd1306_setCursor(4, 0);
    ssd1306_print("SSD1306 DIRECT");
    ssd1306_setCursor(4, 16);
    ssd1306_print("Test 1 2 3 abc");
    long_delay(80);

    /* ---- Tahap 3: fillRect solid (uji blok piksel) ---- */
    ssd1306_fillRect(10, 30, 30, 16, 1);
    long_delay(80);

    /* ---- Tahap 4: drawPixel pola diagonal (uji titik individual) ---- */
    for(int i=0; i<40; i++){
        ssd1306_drawPixel(50 + i, 30 + (i/2), 1);
    }
    long_delay(80);

    /* ---- Tahap 5: hapus sebagian kotak (uji color=0) ---- */
    ssd1306_fillRect(15, 35, 10, 6, 0);
    long_delay(80);

    /* ---- Tahap akhir: tampilkan status di baris bawah ---- */
    ssd1306_setCursor(4, 56);
    ssd1306_print("DEMO SELESAI");

    for(;;){}
}