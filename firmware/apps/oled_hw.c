/* oled_hw.c -- "Hello World" di OLED SSD1306 lewat controller I2C hardware
 * (i2c_master.v), bukan bit-bang. Sama dengan oledprog.c selain flag di bawah. */
#define SSD1306_HW_I2C
#include "ssd1306.h"

int main(){
    ssd1306_begin();
    ssd1306_clearDisplay();
    ssd1306_setCursor(16, 4);
    ssd1306_print("Hello World");
    for(;;){}
}
