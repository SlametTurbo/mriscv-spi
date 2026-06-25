#include "mriscv.h"

/* Kecepatan dasar; -DSPEED=kecil. */
#ifndef SPEED
#define SPEED 0x1000
#endif
#ifndef N_COUNT
#define N_COUNT 256
#endif
#ifndef N_RAND
#define N_RAND 60
#endif

/* Variabel global ter-inisialisasi (.data) -> dimuat bersama image program. */
static unsigned lfsr = 0xACE1u;

/* LFSR 16-bit (Fibonacci, tap 16,14,13,11) -> angka pseudo-acak 8-bit. */
static unsigned rnd8(void){
    unsigned bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1u;
    lfsr = (lfsr >> 1) | (bit << 15);
    return lfsr & 0xFFu;
}

static void show(unsigned v){ led_set(v & 0xFFu); }

/* Mode 1: pencacah biner 0..255 di 8 LED. */
static void mode_counter(void){
    for (int i = 0; i < N_COUNT; i++){ show(i); delay(SPEED); }
}

/* Mode 2: Knight Rider (titik memantul bolak-balik). */
static void mode_knight(void){
    for (int r = 0; r < 3; r++){
        for (int i = 0; i < 8; i++){ show(1u << i); delay(SPEED * 2); }
        for (int i = 6; i >= 1; i--){ show(1u << i); delay(SPEED * 2); }
    }
}

/* Mode 3: isi dari kedua ujung ke tengah, lalu kosongkan (pakai lookup table .rodata). */
static const unsigned char order[8] = {0, 7, 1, 6, 2, 5, 3, 4};
static void mode_fill(void){
    unsigned m = 0;
    for (int i = 0; i < 8; i++){ m |=  (1u << order[i]); show(m); delay(SPEED); }
    for (int i = 0; i < 8; i++){ m &= ~(1u << order[i]); show(m); delay(SPEED); }
}

/* Mode 4: kelap-kelip acak (LFSR). */
static void mode_random(void){
    for (int i = 0; i < N_RAND; i++){ show(rnd8()); delay(SPEED); }
}

/* Mode 5: pola selang-seling 0x55 / 0xAA. */
static void mode_alt(void){
    for (int i = 0; i < 16; i++){ show((i & 1) ? 0xAAu : 0x55u); delay(SPEED * 3); }
}

/* Mode 6: LED ON dari kanan ke kiri.. */
static const unsigned char orderRun[8] = {0, 1, 2, 3, 4, 5, 6, 7};
static void mode_shift(void){
    unsigned q
     = 0;
    for (int i = 0; i < 8; i++){ q |=  (1u << orderRun[i]); show(q); delay(SPEED); }
    delay(SPEED * 3);
    for (int i = 0; i < 8; i++){ q &= ~(1u << orderRun[i]); show(q); delay(SPEED); }

}
int main(void){
    for (;;){
        mode_random();
    }
}
