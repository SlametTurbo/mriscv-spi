/* switch_led_satu.c -- sw0 menyalakan led0. */
#include "mriscv.h"
#define GP(i) GPIO(i)
int main(void){
    for(;;){
        unsigned s = GP(0) & 1u;     /* baca switch 0 */
        GP(0) = (s & 1u) | 0x2u;     /* led0 = switch0 */
    }
}
