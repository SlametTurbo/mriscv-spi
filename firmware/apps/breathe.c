#include "mriscv.h"
/* Efek "napas": 8 LED meredup-menyala mulus via PWM software.
   Di core ~1.5MHz, led_set ~816 siklus -> PWM_STEPS=16 memberi ~115Hz (tak berkedip),
   17 level kecerahan. Berbeda total dari LED Show (on/off) -> bukti ganti program. */
#ifndef PWM_STEPS
#define PWM_STEPS 16
#endif
#ifndef HOLD
#define HOLD 7                /* siklus PWM per level kecerahan (atur kecepatan napas) */
#endif

static void pwm_all(unsigned duty, unsigned cycles){
    for (unsigned c = 0; c < cycles; c++)
        for (unsigned t = 0; t < PWM_STEPS; t++)
            led_set(t < duty ? 0xFFu : 0x00u);
}

int main(void){
    for (;;){
        for (unsigned d = 0; d <= PWM_STEPS; d++) pwm_all(d, HOLD);          /* terang naik */
        for (int d = PWM_STEPS; d >= 0; d--)      pwm_all((unsigned)d, HOLD);/* terang turun */
    }
}
