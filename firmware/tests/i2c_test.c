/* Uji regresi I2C master hardware (slave dummy alamat 7-bit 0x3C di tb).
 * 1) tulis 3 byte (0x00, 0xAE, 0x5C) ke 0x78, 2) tulis pointer 0x10 lalu
 * repeated START baca 2 byte. Hasil dilaporkan lewat LED: byte baca ke-2
 * (0x5A di tb). Alamat salah 0x50 harus NACK -> LED bit tidak berubah. */
#include "mriscv.h"
int main(void){
    unsigned ok = 0;
    i2c_hw_init();
    ok += i2c_hw_write(0x78, I2C_START);
    ok += i2c_hw_write(0x00, 0);
    ok += i2c_hw_write(0xAE, 0);
    ok += i2c_hw_write(0x5C, I2C_STOP);
    ok += (i2c_hw_write(0x50, I2C_START) == 0);        /* alamat salah: NACK */
    i2c_hw_stop();
    i2c_hw_write(0x78, I2C_START);
    i2c_hw_write(0x10, 0);
    i2c_hw_write(0x79, I2C_START);                     /* repeated START */
    unsigned a = i2c_hw_read(0, 0);
    unsigned b = i2c_hw_read(1, I2C_STOP);
    for(;;){
        led_set(a == 0xA5 && b == 0x5A && ok == 5 ? 0x5A : 0xEE);
    }
}
