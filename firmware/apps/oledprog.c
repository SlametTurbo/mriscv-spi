#include "ssd1306.h"

static void long_delay(unsigned n){
    volatile unsigned i, j;
    for(i=0;i<n;i++) for(j=0;j<2000;j++) __asm__ volatile("");
}

int main(){

    ssd1306_begin();
    ssd1306_clearDisplay();
    long_delay(50);

    ssd1306_setCursor(16, 4);
    ssd1306_print("Hello World");
    long_delay(1000);

    for(;;){}
}