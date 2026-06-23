#define GP(i) (*(volatile unsigned *)(0x1040 + (i)*4u))

// Fungsi delay bare-metal agar perubahan angka bisa dilihat mata
void delay(volatile unsigned int count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

/**
 * Fungsi untuk mengirimkan nilai 8-bit ke GPIO.
 * Nilai ini akan langsung tampil di LED dan ter-decode ke Seven Segment.
 */
void tampilkan_ke_hardware(unsigned char nilai) {
    for (unsigned i = 0; i < 8; i++) {
        // Ambil bit ke-i dari data nilai
        unsigned bit = (nilai >> i) & 1u;
        
        // Kirim ke register GPIO per pin:
        // Jika bit bernilai 1 -> tulis 0x3 (data=1, enable=1)
        // Jika bit bernilai 0 -> tulis 0x2 (data=0, enable=1)
        GP(i) = bit ? 0x3u : 0x2u;
    }
}

int main(void) {
    unsigned char counter = 0;

    for (;;) {
        // 1. Kirim nilai counter saat ini ke display
        tampilkan_ke_hardware(counter);

        // 2. Beri jeda waktu (silakan naikkan/turunkan nilai ini sesuai clock CPU Anda)
        delay(15000);

        // 3. Naikkan nilai counter. 
        // Karena bertipe 'unsigned char' (8-bit), setelah 255 (0xFF) ia akan otomatis kembali ke 0
        counter++;
    }

    return 0;
}