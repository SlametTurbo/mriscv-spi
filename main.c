#include "mriscv.h"
int main(void) {
    uint8_t v = 0;
    for (;;) { led_set(v); delay(0x30000); v++; }   // counter 8-bit di GPIO
}
