/* switch_led.c -- baca slide switch, nyalakan LED yang bersesuaian.
 * Membaca GPIO pin i mengembalikan keadaan switch i (pindata[i]) di bit 0.
 * Menulis 0x3 = LED ON (data=1,enable=1), 0x2 = LED OFF (data=0,enable=1).
 *
 * Versi ini meng-cermin-kan 8 switch -> 8 LED. Untuk "1 switch -> 1 LED",
 * cukup pakai pin 0 saja (lihat main_satu di bawah).
 */
#define GP(i) (*(volatile unsigned *)(0x1040 + (i)*4u))

int main(void){
    for(;;){
        for(unsigned i = 0; i < 8; i++){
            unsigned write_idx = i;
            
            if (i == 2) write_idx = 3;
            if (i == 3) write_idx = 2;

            unsigned s = GP(i) & 1u;
            GP(write_idx) = (s & 1u) | 0x2u; 
        }
    }
}
