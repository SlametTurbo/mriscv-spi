#include "mriscv.h"
// Contoh gaya C++ (tanpa heap/STL): objek dengan konstruktor & method.
class Runner {
    unsigned pos = 0;            // .bss / init oleh ctor
public:
    void step() {
        for (unsigned i = 0; i < 8; i++) gpio_pin(i, i == pos);  // satu titik nyala
        pos = (pos + 1) & 7;
    }
};
static Runner r;                 // objek global -> ctor via .init_array
int main() {
    for (;;) { r.step(); delay(0x6000); }   // LED running
}
