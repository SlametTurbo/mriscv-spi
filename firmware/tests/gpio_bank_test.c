/* Uji regresi 2 bank GPIO dalam 1 RTL (basys3_top.v).
 * Bank 2: pin OLED SCL <- encoder DT, OLED SDA <- encoder CLK (silang, agar
 *         salah-sambung terdeteksi). Bank 1: LED <- switch. */
#include "mriscv.h"
int main(void){
    for(;;){
        gpio2_pin(GPIO2_OLED_SCL, gpio2_rd(GPIO2_ENC_DT));
        gpio2_pin(GPIO2_OLED_SDA, gpio2_rd(GPIO2_ENC_CLK));
        led_set(gpio_bus_rd());
    }
}
