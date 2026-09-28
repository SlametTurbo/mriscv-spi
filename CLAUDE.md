# mriscv-spi — Konteks Proyek

Soft-core RISC-V RV32I (`onchipuis/mriscv`) di FPGA Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C), memakai toolchain open-source penuh (openXC7: Yosys + nextpnr-xilinx + fasm2frames + xc7frames2bit), **tanpa Vivado**. Program di-upload ke RAM core saat runtime lewat SPI loader (Total Phase Cheetah), sehingga ganti firmware **tidak perlu re-synthesis**.

Proyek skripsi S1. Semua penjelasan dan komentar kode dalam Bahasa Indonesia.

---

## Perintah build

```bash
make synth XDC=basys3_spi.xdc    # sintesis -> spi.bit (~5-10 menit, chipdb pertama kali lebih lama)
make flash                        # flash bitstream ke board via JTAG
make build FW=<nama>              # compile firmware saja -> <nama>.bin
make prog  FW=<nama>              # compile + upload via SPI (cepat, <2 detik)
make check-tools                  # verifikasi toolchain terpasang
```

Struktur sibling yang diharapkan Makefile (disiapkan oleh `./install.sh`):
```
~/demo-projects/
  openXC7.mk      <- Makefile mencari di ../openXC7.mk
  chipdb/         <- CHIPDB = $(abspath ../chipdb)
  mriscv-spi/     <- repo ini
```

---

## Fakta arsitektur (terverifikasi, jangan diasumsikan ulang)

| Aspek | Nilai |
|---|---|
| Clock oscillator board | 100 MHz (pin W5) |
| Clock core sekarang | `clk100/2` = **50 MHz** via `wire clk = divcnt` (toggle-FF 1 bit) — naik dari 1.5625 MHz lama |
| **Fmax hasil P&R (terkini)** | **Berayun cukup lebar antar-run: 57.22-71.42 MHz** teramati (2026-09-28, banyak run beruntun: 71.30, 57.22, 57.48, 62.73, 58.72, 71.42 MHz — RTL nyaris identik tiap run). **PENTING: `nextpnr-xilinx` pakai seed TETAP secara default** — `make synth` ulang dgn RTL sama persis = hasil P&R IDENTIK (bukan random beneran). Untuk dapat variasi nyata (coba cari margin lebih baik), WAJIB `make clean` dulu (Make skip `synth` kalau `.bit` sudah ada & tidak tahu flag berubah) lalu `make synth XDC=basys3_spi.xdc PNR_ARGS="-r"` (randomize seed) atau `PNR_ARGS="--seed N"`. Margin ke clock 50 MHz jadi **~12-43%** tergantung seed — **JANGAN asumsikan margin selalu sehat**, selalu cek Fmax run yang AKAN di-flash sebelum demo penting. Angka 66.16 MHz sangat lama & 67.57/61.49 MHz (sebelum UART) **SUDAH USANG**, jangan dipakai lagi. |
| RAM | **32 KB** (`SP32B1024`, 8192 words x 32-bit, `A[12:0]`) — naik dari 4 KB lama (1024 words, `A[9:0]`) |
| BRAM tersedia di chip | ~225 KB — jadi RAM sekarang pakai ~14.2% |
| Arsitektur core | **Multi-cycle FSM 7-state**, BUKAN pipeline |
| Hazard control unit | **Tidak ada, dan tidak diperlukan** (tidak ada instruksi overlap) |

FSM: `S0_fetch -> S1_decode -> S2_exec -> S3_memory -> (kembali S0)`, plus `S4_trap` (halt permanen) dan wait-state `SW0_fetch_wait`/`SW3_mem_wait` untuk latensi BRAM sinkron.

### ⚠️ Jalur negedge di `AXI_SP32B1024.v` — DISENGAJA, JANGAN DIPATCH NAIF

1. **Margin Fmax ~74%** (lihat tabel di atas) — cukup sehat, tapi static timing analysis tetap tidak menangkap variasi suhu/tegangan nyata. Tetap waspada kalau demo di kondisi board yang berbeda dari dev environment.
2. **`AXI_SP32B1024.v` memakai `always @(negedge CLK)`** (baris ~45 dan ~123) — **INI DISENGAJA, BUKAN BUG**. Komentar asli di kode ("we provide the signals in negedge, because the setup and hold sh*t" / "Thanks god, the memory provides their data in posedge") menjelaskan alasannya: `A`/`CEN`/`WEN` sengaja di-latch setengah-siklus SETELAH state machine AXI (`reading1`/`writting1`/dst, yang jalan di posedge) settle, supaya `SP32B1024` (posedge murni) dapat alamat yang sudah stabil penuh setengah periode sebelum dipakai — bukan setengah-siklus yang sama.
   - **Sudah diuji empiris (2026-08-31, simulasi `iverilog` pakai testbench SPI nyata) DAN TERBUKTI SALAH:** mengganti `negedge`→`posedge` di kedua baris tanpa restrukturisasi lain **merusak fungsi tulis SRAM total** (GPIO tetap jalan karena peripheral terpisah, tapi `mem[]` tidak pernah ke-update, burst write gagal semua). Penyebab: `SP32B1024` jadi membaca `A` versi SATU SIKLUS TERTINGGAL (non-blocking assignment, semua flip-flop di edge yang sama pakai nilai pre-edge) alih-alih alamat yang baru saja di-decode.
   - **Patch sudah di-revert. JANGAN diulangi** tanpa redesain pipeline yang benar (mis. menunda flag `writting`/`reading` satu siklus tambahan supaya hubungan waktunya tetap tepat). Ini bukan task TODO — ini keputusan desain yang sudah diverifikasi dan ditutup, kecuali ada rencana redesain pipeline penuh.
   - Di clock lama (1.5625 MHz) setengah-periode negedge-nya 320 ns, longgar. Di **50 MHz sekarang, setengah-periode cuma ~10 ns** — margin di jalur ini lebih ketat dari yang tersirat laporan Fmax biasa (yang menghitung per periode penuh). Tapi ini murni soal margin STA yang perlu diawasi, BUKAN kegagalan fungsional — sistem saat ini FUNGSIONAL dan terverifikasi di hardware nyata pada 50 MHz.
3. Kalau demo di sidang tiba-tiba tidak stabil (kadang jalan kadang tidak) padahal kemarin normal di dev environment — margin timing di jalur negedge ini kandidat penyebab pertama yang dicurigai. Tapi **solusinya BUKAN patch negedge→posedge** (sudah terbukti merusak) — kalau perlu diagnosis lebih jauh, mulai dari menambah margin clock (turunkan sedikit dari 50MHz) dulu, bukan sentuh AXI_SP32B1024.

### Peta alamat AXI (dari `impl_axi.v` baris 41-42)

**Setelah ekspansi RAM 4 KB -> 32 KB** (DAC/ADC/GPIO direlokasi ke `0x4000+` supaya tidak tabrakan dengan SRAM yang sekarang mengisi `0x000`-`0x1FFF`):
```
addr_mask = {32'h00000000, 32'h0000000F, 32'h00000001, 32'h00000001, 32'h00001FFF}
addr_use  = {32'h04000000, 32'h00004010, 32'h00004008, 32'h00004000, 32'h00000000}
```
Dibaca terbalik (slave 0 = elemen terakhir):

| Slave | Peripheral | Word addr | Catatan |
|---|---|---|---|
| 0 | SRAM | `0x0000`-`0x1FFF` | 8192 words = 32 KB |
| 1 | DAC | `0x4000` | **Tidak terpakai** — port `dac_data` menggantung |
| 2 | ADC | `0x4008` | **Tidak terpakai** — di-tie ke `1'b0`/`10'd0` |
| 3 | GPIO | `0x4010`-`0x401F` | byte addr = `0x10040 + i*4` (lama: `0x1040 + i*4`, sebelum relokasi) |
| 4 | SPI slave | `0x04000000` | output `sc`/`ss`/`sd` menggantung |
| 5 | UART TX | `0x4020` | byte addr `0x10080`. TX-only, 9600 8N1 fixed. Lihat "UART hardware" di bawah |

### Bus: AXI, bukan APB

Proyek ini pakai jalur **AXI4-Lite-style** (`mriscv/mriscv_axi/*` — `impl_axi`, `axi4_interconnect`, `AXI_SP32B1024`, `spi_axi_master/slave`, DAC/ADC/GPIO AXI). Makefile hanya include folder ini (`Makefile:44-52`), top module instansiasi `impl_axi` (`basys3_top.v:40`).

Upstream `onchipuis/mriscv` juga punya varian **APB** di `mriscv/mriscv_apb/` (`impl_axi_apb.v`, `gpioAPB.v`, `ADC/DAC_interface_APB.v`) — **tidak dipakai sama sekali** di proyek ini, tidak direferensikan Makefile/XDC/top module manapun. Jangan bingung kalau grep nemu file APB itu di repo.

### Interkoneksi GPIO

GPIO = 1 slave AXI generik (`completogpio`, slave index 3 → word addr `0x4010`-`0x401F`, byte `0x10040+i*4`). Internal: `macstate2` (FSM handshake AXI) → `latchW`×2 (latch alamat pin 0-7) → `decodificador`×2 (decode ke one-hot 8-bit) → `flipsdataw`×8 (tulis: `Wdata[1:0]` → `datanw[i]`+`DSE[i]`) / baca langsung mux `pindata[LRAddress]` → `Rdata[0]`. `Tx`/`Rx` (dari `flipflopRS`) ada di modul tapi **dangling di semua top module yang ada** — abaikan.

Tiap pin GPIO = 2 sinyal fisik terpisah berbagi 1 indeks: `pindata[7:0]` (input ke core) dan `datanw[7:0]` (output dari core). Makna tiap bit ditentukan bebas oleh top module, bukan hardcoded di `completogpio`:
- `basys3_top.v`: `pindata` = switch (sync 2-FF), `datanw` → LED + 7-segment 2-digit.
- `oled-with-encoder/basys3_top.v`: `pindata[1:0]` = encoder CLK/DT, `datanw[0:1]` → OLED SCL/SDA lewat tri-state open-drain (`gdat[i] ? 1'bz : 1'b0`) yang dibuat di top module, bukan di `completogpio`.

### Dua AXI master: `mriscvcore` vs `spi_axi_master`

`impl_axi.v:39` — `masters = 2`. Master 0 = `mriscvcore` (CPU), master 1 = `spi_axi_master` (loader SPI, parse frame `{instr[2],addr[32],data[32]}`, `instr=10`→write AXI langsung ke slave manapun termasuk RAM/GPIO, `instr=00`→NOP kontrol reset).

**Arbitrase real disediakan** (`axi4_interconnect.v:112-161`, round-robin via `counter_rrequests`/`counter_wrequests`) tapi **jarang benar-benar dipakai** karena desain memakai mutual-exclusion lewat reset: output `PICORV_RST` dari `spi_axi_master` (`spi_axi_master.v:14,45,68-69`, di-set dari bit `data[0]` frame NOP) disambung langsung jadi `rstn` CPU (`impl_axi.v:199,34`). Selama loader menahan `PICORV_RST=0`, CPU di-reset dan FSM-nya tidak pernah assert `AWvalid`/`ARvalid` → otomatis pasif dari bus. Alur upload normal: host tahan CPU reset → burst-write isi RAM via master 1 → lepas reset (NOP `data[0]=1`) → CPU mulai fetch. Jadi cuma 1 master yang benar-benar aktif tiap saat, bukan dua master berebut bus bersamaan.

~~Catatan kecil: `en_rrequests`/`en_wrequests` ditandai `TODO: NOT ASSIGNED ALREADY` di deklarasi wire-nya~~ **KOREKSI (2026-09-28): ini SALAH BACA sebelumnya** — komentar TODO itu cuma di baris deklarasi (`axi4_interconnect.v:116-117`), tapi keduanya BENAR di-assign lebih jauh di bawah (`axi4_interconnect.v:344-345`: `assign en_rrequests = ~rtrans & ~is_rrequests; assign en_wrequests = ~wtrans & ~is_wrequests;`). Counter round-robin memang digated dengan benar (cuma maju kalau tidak ada transaksi pending). Jangan percaya kesimpulan dari grep sepotong tanpa baca file penuh — pelajaran ini sendiri jadi contoh baru untuk poin "verifikasi sebelum klaim" di bagian bawah.

### UART hardware (TX-only) — SELESAI & JALAN DI HARDWARE (dengan workaround GCC inline — baca sampai habis sebelum pakai)

Implementasi 2026-09-28. Slave AXI baru (`mriscv/mriscv_axi/UART_TX/uart_tx.v`), slave index 5, word addr `0x4020` (byte `0x10080`), mask exact-match (`32'h00000000`). Baud rate **fixed 9600 8N1**, dihitung dari parameter `CLK_HZ=50_000_000` yang di-pass eksplisit saat instansiasi di `impl_axi.v` — **kalau clock core diubah, parameter ini WAJIB ikut disesuaikan**.

**Semantik register (byte `0x10080`) — versi TERKINI (non-blocking):**
- **Tulis** byte apapun → kirim 1 byte UART. Transaksi AXI **SELALU cepat** (beberapa siklus, non-blocking, persis seperti GPIO/DAC/ADC) — kalau transmitter masih sibuk, byte yang ditulis **diam-diam diabaikan** oleh hardware.
- **Baca** → bit0 = busy (1 = sedang transmit).
- HAL (`mriscv.h`): `uart_putc()` polling `uart_busy()` di SOFTWARE dulu sebelum menulis (supaya byte tidak pernah hilang), `uart_puts()` dibungkus `do-while` (backward-branch saja).

**Pin fisik:** `uart_txd` → `A18` (`basys3_spi.xdc`), kabel yang SAMA dengan JTAG programming (channel B FTDI FT2232HQ onboard Basys3 → virtual COM port). ⚠️ Pin ini belum diverifikasi ke reference manual Basys3 asli.

**Perjalanan debugging (2026-09-28, penting buat siapapun lanjutin ini):**

1. **Bug #1 (ditemukan & diperbaiki):** instansiasi `axi4_interconnect` di `impl_axi.v` awalnya cuma override `.addr_mask()`/`.addr_use()`, TIDAK override `.masters()`/`.slaves()` — nggak kelihatan sebelumnya karena kebetulan sama dengan default param. Ketahuan dari warning port-width `iverilog` begitu `slaves` naik ke 6. **Instance KEDUA dari kelas bug yang sama persis dengan item #6 "JANGAN DIRUSAK"** (RAM expansion dulu). Fix: `.masters(masters), .slaves(slaves)` eksplisit.

2. **Simulasi unit `uart_tx.v` sendirian PASS total**, tapi begitu diuji di **hardware fisik**, firmware apapun yang menulis UART **lebih dari 1x** (bahkan cuma 2x manual call tanpa loop) bikin CPU **hang permanen** (LED berhenti total). Firmware yang cuma nulis 1x selalu OK.

3. **Isolasi bertahap di hardware** (bukan simulasi — simulasi CPU penuh custom yang saya buat TERBUKTI TIDAK BISA mereproduksi hang ini sama sekali, kemungkinan besar karena ini bug timing/marginal yang cuma muncul di silikon nyata, bukan bug logika murni yang kelihatan di simulasi zero-delay iverilog):
   - `main.c` (write-only, tanpa loop baca) → selalu OK.
   - `uart_probe.c` (1x tulis langsung) → OK.
   - `uart_probe2.c` (2x tulis manual berurutan, tanpa loop) → OK (bahkan di bitstream lama yang punya bug).
   - `uart_probe3/4.c` (`uart_puts` via loop asli, walau cuma **1 karakter**) → **HANG**.
   - `gpio_probe.c` (loop yang sama, target GPIO bukan UART) → **HANG JUGA** → jadi ini BUKAN soal UART spesifik, tapi soal CPU/loop secara umum.
   - `encoder_test.c` (kode YANG SUDAH ADA di repo sebelum sesi ini: baca 8 switch lalu tulis 8 LED, tanpa delay) → **JUGA HANG** di bitstream awal.
   - **Pola yang konsisten:** program **write-only** (tanpa pernah baca DATA — instruksi fetch tidak dihitung) selalu aman; program apapun yang punya **pembacaan data (`lbu`/`lw`) diikuti penulisan (`sw`)** — apapun bentuk loop/branch-nya, apapun peripheral-nya — brisiko hang.

4. **Fmax P&R ternyata SANGAT bervariasi antar-run untuk RTL identik** (bitstream yang lagi kepasang waktu bug ini ketahuan cuma Fmax **57.22 MHz**, jauh di bawah histori ~67-71MHz — margin ke 50MHz cuma ~12%). **`nextpnr-xilinx` pakai seed TETAP secara default** (`make synth` ulang dengan RTL sama = hasil P&R IDENTIK) — buat variasi nyata WAJIB pakai `PNR_ARGS="-r"` (randomize seed) atau `PNR_ARGS="--seed N"`, dan WAJIB `make clean` dulu (Make tidak tahu `PNR_ARGS` berubah, `synth` ke-skip kalau `.bit` sudah ada).
   - Resynth dengan margin lebih baik (**62.73 MHz**) → `encoder_test.c` **JADI JALAN NORMAL**. Konfirmasi kuat: setidaknya SEBAGIAN dari hang ini murni soal timing closure marginal (kelas masalah sama dengan negedge `AXI_SP32B1024` yang sudah didokumentasikan), BUKAN bug logika — tapi lihat poin 6, ternyata bukan cerita lengkapnya.

5. **Redesain `uart_tx.v` jadi non-blocking** (write SELALU cepat, drop diam-diam kalau busy, "tunggu idle" dipindah ke polling software) — menghilangkan pola unik "menahan AXI ~52080 siklus" yang cuma dialami UART (GPIO/DAC/ADC selalu cepat). Saat redesain ini, **ketahuan race condition nyata**: window 1 siklus antara `start_pulse` di-assert dan `tstate` benar-benar pindah dari `S_IDLE`, di mana write kedua yang datang pas di window itu bisa menimpa `wdata_byte` sebelum byte pertama sempat mulai transmit. Fix: `busy` sekarang ikut menghitung `start_pulse` (`wire busy = (tstate!=S_IDLE) || start_pulse;`). Testbench unit di-update sesuai semantik baru, PASS semua.

6. **MASIH HANG** bahkan setelah #4 (margin 71.42 MHz, jauh lebih sehat) DAN #5 (non-blocking) digabung — `uart_probe.c` (1 tulis + polling) OK, tapi `uart_probe3.c` (loop poll-busy → tulis → baca-karakter-berikutnya → ulang, walau cuma "Hi\r\n" 4 karakter) **TETAP hang**.

7. **Workaround `uart_puts()` tanpa polling** (baca `*s` + tulis UART + `delay()` tetap, TANPA `uart_busy()` di dalam loop) — **MASIH HANG JUGA**, meski cuma tersisa SATU baca (`lbu` karakter string) per iterasi.

8. **ROOT CAUSE SEBENARNYA KETEMU (akhirnya):** ganti `uart_hello.c` supaya kirim tiap karakter via pemanggilan `uart_putc('H'); uart_putc('e'); ...` literal berulang (21×, tanpa loop atas string, tanpa baca RAM sama sekali) — **MASIH HANG**! Investigasi disassembly: `uart_putc` yang dideklarasikan `static inline` di `mriscv.h` ternyata **TIDAK di-inline oleh GCC -Os** begitu dipanggil >~3-4 kali (GCC pilih hemat kode, emit `jal`/`ret` sungguhan alih-alih 21 salinan inline). Setiap `jal` menulis `ra` (return address, lewat `PC_ORIG` di `UTILITY.v`) dan `ret` (`jalr x0,0(ra)`) membacanya kembali — **pola tulis-lalu-baca REGISTER berulang, bukan cuma soal AXI/memori sama sekali!** Fix: paksa `uart_busy()`/`uart_putc()` selalu inline penuh via `__attribute__((always_inline))` di `mriscv.h` (`inline` biasa cuma hint, GCC boleh mengabaikannya). Setelah ini: **BERHASIL** — LED counting normal DAN teks "Hello UART @ mriscv" muncul benar di serial terminal (`/dev/ttyUSB1`, 9600 8N1, lewat kabel USB JTAG yang sama).

**KESIMPULAN AKHIR:** bug core-nya **BUKAN spesifik soal AXI read-then-write** seperti dugaan awal — itu cuma SALAH SATU gejala dari kelas bug yang lebih umum: **register file (`REG_FILE.v`) rapuh terhadap pola tulis-lalu-baca register yang RAPAT/berulang**, entah datanya dari AXI load (`lbu`/`lw`) MAUPUN dari mekanisme intrinsik CPU sendiri (`jal` menulis `ra`, `ret` membacanya). Kandidat kuat penyebab: `REG_FILE.v`'s `true_dpram_sclk` (distributed RAM 32×32-bit, port read+write SAMA, `addr_a = rdw_rsrn?rdi:rs1i`) mengandalkan behavior read-during-write yang mungkin beda antara simulasi Verilog (`<=` non-blocking, selalu baca nilai lama — makanya simulasi CPU penuh custom di sesi ini TIDAK PERNAH bisa mereproduksi hang manapun) vs LUT-RAM Xilinx hasil sintesis Yosys (`ram$rdreg`, kemungkinan policy write-first/read-first/no-change beda) — **masih hipotesis, belum diverifikasi langsung**, tapi sekarang funsi dengan bukti jauh lebih kuat & spesifik (repro minimal: fungsi non-inline yang dipanggil berulang).

**SOLUSI YANG DIPAKAI SEKARANG (kerja, tapi WORKAROUND bukan fix akar masalah):**
- `mriscv.h`: `uart_busy()` dan `uart_putc()` dipaksa `__attribute__((always_inline))`.
- `uart_hello.c`: kirim string via pemanggilan `uart_putc(literal)` berulang langsung (bukan `uart_puts(char*)` yang baca RAM runtime).
- `uart_puts(const char*)` di `mriscv.h` MASIH ADA tapi **BELUM terbukti aman untuk string RUNTIME** (baca alamat dari pointer, bukan literal) — kalau mau pakai, uji dulu di hardware, jangan asumsikan aman cuma karena `uart_putc` sekarang always-inline (readnya `*s` sendiri tetap AXI load dari RAM).
- **IMPLIKASI LEBIH LUAS buat firmware lain di proyek ini:** fungsi `static inline` APAPUN di `mriscv.h` (`gpio_pin`, `led_set`, `gpio_rd`, dst) BERISIKO sama kalau suatu saat dipanggil cukup banyak kali sehingga GCC -Os memutuskan TIDAK meng-inline-nya (jadi `jal`/`ret` sungguhan). Sejauh ini semua firmware yang ada kemungkinan besar aman karena pemanggilannya sedikit/pendek, tapi ini **RISIKO LATEN** yang belum di-audit menyeluruh. Kalau firmware baru tiba-tiba hang tanpa alasan jelas, cek dulu disassembly (`<nama_fw>.dump`) apakah ada `jal`/`ret` berulang ke fungsi HAL yang harusnya inline.

**Testbench unit** (`mriscv/mriscv_axi/UART_TX/uart_tx_tb.v`) PASS semua untuk desain non-blocking `uart_tx.v` (termasuk verifikasi race condition fix) — RTL UART TX-nya sendiri SUDAH BENAR dan bukan sumber masalah sama sekali; seluruh saga ini adalah bug core CPU/toolchain, bukan bug hardware UART yang saya tulis. **Elaborate check** bersih.

**Kalau mau lanjutin investigasi root cause di masa depan:** mulai dari `REG_FILE.v`'s `true_dpram_sclk`, cek behavior read-during-write hasil sintesis Yosys `synth_xilinx` utk distributed RAM 32×32, bandingkan dengan asumsi simulasi. Simulasi CPU penuh custom di sesi ini terbukti TIDAK RELIABLE untuk mereproduksi bug ini (perlu `force PICORV_RST=1` manual, dan tidak sekalipun berhasil mereproduksi hang meski persis meniru program yang hang di hardware) — kemungkinan besar karena ini genuinely perbedaan simulasi-vs-sintesis, bukan bug logika yang kelihatan di RTL behavioral. Testbench yang HANYA menyorot `REG_FILE.v` (bukan seluruh CPU), dibandingkan hasil post-synthesis netlist simulation (bukan cuma behavioral iverilog), kemungkinan besar dibutuhkan untuk konfirmasi pasti.

---

## Fitur core yang ADA di source tapi TIDAK AKTIF

Ini temuan hasil audit RTL, penting untuk tidak salah asumsi:

- **`MULT.v`** — implementasi Booth multiplier lengkap ada, tapi **tidak pernah dipanggil dari `FSM.v`** (nol referensi). Perkalian hardware efektif tidak berfungsi. Konfirmasi tambahan: 0 primitif DSP48 di netlist hasil sintesis.
- **`IRQ.v`** — timer interrupt controller ada, tapi instansiasinya **di-comment** di `impl_axi.v` (`//.outirr (irq ),`).
- **Division** — **tidak ada modul DIV sama sekali**. Test resmi upstream diberi akhiran `.disabled` (`tests/div.S.disabled`, `tests/divu.S.disabled`) oleh pengembang aslinya.

---

## Aturan firmware (bare-metal, wajib dipatuhi)

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
    -ffreestanding -Os -T link_c.ld crt0.S <prog>.c -o <prog>.elf
```

- **JANGAN pakai operator `/` dan `%`** — butuh `__divsi3`/`__modsi3` dari libgcc yang tidak tersedia di `-nostdlib`. Ganti dengan loop pengurangan manual. Ini penyebab error linking yang berulang kali muncul.
- **`crt0.S` wajib disertakan** dalam perintah compile (setup stack pointer, nol-kan `.bss`, panggil `main()`). Tanpa ini binary tidak punya entry point valid.
- Sertakan `#include <stdint.h>` kalau memakai `uint8_t` dkk.
- Driver ditulis **header-only (`static inline`)** — menghemat 169 byte per program dibanding split `.h`/`.c` (terukur: 2135 vs 2304 byte). Pertahankan pola ini.
- RAM sekarang 32 KB (dulu 4 KB) — masih tetap cek ukuran dengan `riscv64-unknown-elf-size` setelah compile untuk kebiasaan baik.
- `link_c.ld` LENGTH sudah diupdate 4K→32K — kalau bikin linker script baru untuk firmware baru, pastikan ikut 32K bukan nyalin dari referensi lama yang masih 4K.

### GPIO HAL (`mriscv.h`)
- Tulis: `gpio_pin(i, v)` → tulis `(v&1)|0x2` ke `0x10040+i*4` (base direlokasi dari `0x1040` setelah ekspansi RAM). Bit1 = DSE (drive strength enable, warisan ASIC, selalu di-set 1).
- Baca: `gpio_rd(i)` → ambil bit0 dari alamat yang sama.
- `pindata` (input) dan `datanw` (output) adalah **sinyal terpisah** yang cuma berbagi indeks — pin index sama bisa dipakai untuk input DAN output karena terhubung ke pin fisik berbeda di top module.
- **3 file firmware punya definisi `GP(i)` sendiri** (bukan lewat `mriscv.h`): `switch_led.c`, `sevensegment.c`, `switch_led_satu.c` — semuanya sudah diupdate ke base `0x10040`. Kalau bikin firmware baru dengan pola serupa (define alamat GPIO manual, bukan include `mriscv.h`), JANGAN lupa base barunya.

### OLED SSD1306 (`ssd1306.h`)
Dual-mode via `#define SSD1306_USE_BUFFER` sebelum `#include`:
- **DIRECT** (default): tiap draw langsung kirim I2C, `display()` = no-op, ~8 byte RAM
- **BUFFER**: gambar ke `ssd1306_buf[1024]`, `display()` wajib dipanggil, +1024 byte RAM

I2C sepenuhnya **bit-bang software** (tidak ada peripheral I2C hardware). Open-drain dibuat di RTL top module:
```verilog
assign oled_scl = gdat[0] ? 1'bz : 1'b0;
assign oled_sda = gdat[1] ? 1'bz : 1'b0;
```
Command init SSD1306 = 25 perintah. Yang krusial: `0x8D,0x14` (charge pump — lupa ini = layar blank), `0x20,0x00` (horizontal addressing mode).

**Kalibrasi timing setelah clock naik ke 50 MHz:** `ihold()` di file-file OLED/I2C (folder `oled-with-encoder/`) sudah disesuaikan 4× (clock domain itu naik dari 12.5→50 MHz). Kalau bikin firmware I2C baru di luar folder ini, cek dulu apakah `ihold()`-nya sudah dikalibrasi atau masih pakai delay lama.

### Wiring OLED + Encoder (referensi cepat)

| Fungsi | Pin Basys3 | Pmod |
|---|---|---|
| OLED SCL | `K17` | JC1 |
| OLED SDA | `M18` | JC2 |
| Encoder CLK | `A14` | JB1 |
| Encoder DT | `A16` | JB2 |
| Encoder SW | `B15` (JB3) | **JANGAN disambungkan ke FPGA** |
| SPI SCLK | `J1` | JA1 |
| SPI MOSI | `L2` | JA2 |
| SPI CS | `J2` | JA3 |
| SPI MISO | `G2` | JA4 |

Semua pin OLED + encoder butuh `PULLUP true` di XDC.

---

## JANGAN DIRUSAK — hal yang sudah diperbaiki dengan susah payah

1. **Blok `initial` di `SP32B1024.v`** yang menol-kan memori. Tanpa ini isi BRAM tidak terdefinisi setelah konfigurasi Artix-7 → boot gagal acak (bug yang sulit dilacak).
2. **Pin `enc_sw` TIDAK boleh disambungkan** ke top module. Pin mengambang terbaca LOW acak → memicu reset software terus-menerus (root cause bug "encoder stuck di 00").
3. **`CHIPDB = $(abspath ../chipdb)`** — harus absolute path, kalau relatif `bbasm` gagal tulis.
4. **`spi_axi_master.v` sudah ditulis ulang** jadi single-clock domain (445 → 101 baris). Jangan kembalikan ke versi upstream yang multi-clock.
5. **SCLK SPI loader ≤ ~1/4 clock core.** Sekarang dipakai 100 kHz. Kalau clock core dinaikkan, batas ini jadi lebih longgar (bukan lebih ketat).
6. **`axi4_interconnect` di-instansiasi TANPA override parameter di `impl_axi.v` itu bug, bukan gaya penulisan.** `axi4_interconnect.v` punya parameter `addr_mask`/`addr_use` SENDIRI dengan default hardcoded (peta alamat lama, 4 KB). `impl_axi.v` juga punya localparam `addr_mask`/`addr_use` bernama SAMA, tapi keduanya modul/scope BERBEDA — kalau instansiasinya cuma `axi4_interconnect inst_axi4_interconnect(...)` tanpa `#(.addr_mask(addr_mask), .addr_use(addr_use))`, localparam di `impl_axi.v` TIDAK PERNAH benar-benar dipakai; decoder AXI diam-diam tetap jalan dengan peta alamat default lama walau `impl_axi.v` "kelihatannya" sudah diubah. Ini pernah bikin relokasi GPIO/DAC/ADC + ekspansi RAM 32 KB kelihatan gagal total (GPIO tidak merespons, tapi tanpa hang) padahal RTL sudah benar — baru ketahuan lewat simulasi `iverilog`, bukan dari inspeksi source. **Selalu declare override parameter eksplisit saat instansiasi modul yang punya parameter alamat/konfigurasi bernama sama dengan localparam di parent.**
7. **JANGAN percaya klaim "sudah dipatch" atau "ini bug" tanpa verifikasi langsung (diff ke upstream ATAU simulasi fungsional).** Dua pelajaran nyata dari proyek ini:
   - Patch negedge→posedge di `AXI_SP32B1024.v` sempat tercatat "selesai" padahal tidak pernah diterapkan — ketahuan lewat `diff` ke upstream.
   - Sebaliknya: `negedge` itu sendiri sempat diasumsikan "bug yang perlu diperbaiki" (termasuk oleh saran sebelumnya di file ini), padahal setelah diuji lewat SIMULASI FUNGSIONAL, terbukti **disengaja dan penting** — patch naif ke posedge justru merusak tulis SRAM total. Cek dulu lewat simulasi sebelum asumsi sesuatu itu "bug", terutama untuk pola timing yang terlihat tidak lazim tapi mungkin punya alasan desain.
   - Cara verifikasi diff cepat: `diff <(tr -d '\r' < mriscv/mriscv_axi/AXI_SP32B1024/AXI_SP32B1024.v) <(curl -s https://raw.githubusercontent.com/onchipuis/mriscv/master/mriscv_axi/AXI_SP32B1024/AXI_SP32B1024.v | tr -d '\r')`

---

## Catatan toolchain (openXC7)

- Paket `openxc7` **tidak ada di Snap Store publik** — install lewat `.snap` dari GitHub Releases (`openXC7/yosys-snap`, `openXC7/openXC7-snap`). Lihat `install.sh`.
- **`pypy3` wajib** (dipakai `bbaexport.py` untuk generate chipdb) — bukan bagian dari paket snap, install terpisah via apt.
- **Tri-state internal ditangani otomatis oleh Yosys.** `axi4_interconnect.v` masih berisi `{sword{1'bz}}` dengan parameter default `addressing=0` (mode tri-state), tapi `synth_xilinx` menjalankan **TRIBUF pass** yang mengonversinya jadi mux otomatis. Terverifikasi: 0 primitif TBUF di netlist, 0 error. **Jangan buang waktu menulis ulang jadi OR-mux manual.**
- Warning `"Yosys has only limited support for tri-state logic"` (10 baris di `axi4_interconnect.v` + 1 baris di `spi_axi_slave.v:164`) itu **normal dan aman** — bukan error.
- **nextpnr mencetak Fmax DUA KALI per run** — laporan pertama (biasanya lebih rendah) adalah estimasi pasca-*placement* SEBELUM routing; laporan KEDUA (setelah baris log `Router1 time ...`) adalah angka final pasca-routing yang sebenarnya. **Selalu pakai angka kedua/terakhir**, jangan salah kutip yang pertama.
- Fmax bisa bervariasi antar-run untuk RTL yang identik (P&R pakai simulated annealing, ada elemen non-deterministik) — kalau angka Fmax berubah beberapa MHz antar sintesis tanpa RTL berubah, itu normal, bukan tanda regresi. Contoh nyata dari proyek ini: RTL identik, dua run berbeda menghasilkan 61.49 MHz dan 67.57 MHz.

---

## Task yang direncanakan (prioritas)

### Prioritas 1 — murah, dampak besar
1. ~~**Naikkan clock core.**~~ **SELESAI & TERVERIFIKASI DI HARDWARE** — `wire clk = divcnt[5]` (÷64, 1.5625 MHz) diganti `divcnt` toggle-FF (÷2, **50 MHz**). Upload SPI + jalannya firmware (ledshow, encoder+OLED) sudah diuji di board fisik dan berfungsi. `SPEED` di `ledshow.c` disesuaikan 32x, `ihold()` di file-file OLED/I2C disesuaikan 4x.
2. **Sambungkan `trap` ke LED.** Saat ini `wire trap` dideklarasikan tapi menggantung. `assign led[7] = trap;` → indikator visual kalau core hang. Berguna untuk debug kalau suatu saat margin timing bermasalah di kondisi tertentu.
3. **Pakai 4 digit seven-segment** (sekarang cuma 2: `assign an = digsel ? 4'b1101 : 4'b1110`).

~~4. Patch negedge→posedge di `AXI_SP32B1024.v`~~ — **DIBATALKAN, JANGAN DIKERJAKAN.** Sudah diuji lewat simulasi dan terbukti merusak fungsi tulis SRAM. Lihat penjelasan lengkap di bagian "Jalur negedge... DISENGAJA" di atas. Kalau margin timing suatu saat jadi masalah nyata, opsi yang aman adalah turunkan clock sedikit (mis. balik ke pembagi yang menghasilkan ~25-33 MHz), BUKAN sentuh pola negedge ini.

### Prioritas 2 — usaha sedang
5. ~~**Perbesar RAM 4 KB → 16/32 KB.**~~ **SELESAI (32 KB) & TERVERIFIKASI** — `SP32B1024` depth 1024→8192 & `A` jadi `[12:0]`, `AXI_SP32B1024` output `A` diperlebar sama, `addr_mask` SRAM `0x3FF`→`0x1FFF`, DAC/ADC/GPIO direlokasi ke `0x4000+`, `GPIO()` base di `mriscv.h` + 3 file firmware yang punya `GP(i)` sendiri (`switch_led.c`, `sevensegment.c`, `switch_led_satu.c`) diupdate ke `0x10040`. `link_c.ld` LENGTH 4K→32K. Sempat ada bug kritis (lihat item #6 di "JANGAN DIRUSAK") yang membuat relokasi/ekspansi ini awalnya tidak berpengaruh sama sekali secara fungsional; sudah diperbaiki dan dikonfirmasi lewat simulasi `iverilog` + uji hardware nyata.
6. **Pisahkan LED dan seven-segment.** Keduanya sekarang baca `gpio_datanw` yang sama. Register DAC `0x4000` (baru, dulu `0x400`) tidak terpakai — bisa jadi sumber data independen.
7. ~~**UART hardware** (`uart_tx.v`)~~ — **SELESAI & JALAN DI HARDWARE ASLI** (`uart_hello.c` terverifikasi: LED counting + teks muncul benar di serial 9600 8N1). Baca detail lengkap di bagian "UART hardware (TX-only)" di atas — jangan cuma baca ringkasan ini, ada temuan bug core CPU (bukan spesifik UART) yang harus dipahami sebelum pakai `uart_puts(char*)` dengan string runtime atau menulis firmware HAL baru. RTL `uart_tx.v` sendiri sudah benar dari awal; masalahnya ternyata di GCC -Os yang tidak selalu inline fungsi `static inline` + kerapuhan `REG_FILE.v` terhadap pola tulis-lalu-baca register. RX belum dikerjakan.
8. **PWM hardware** (counter-compare) — membebaskan CPU dari loop toggle software.

### Prioritas 3 — proyek besar, buat branch terpisah
9. Sambungkan `MULT.v` ke FSM (jadikan RV32IM parsial)
10. Aktifkan `IRQ.v` (uncomment + handling PC save/restore)
11. Tulis unit division dari nol
12. **Opsional, kalau margin timing jadi masalah:** redesain pipeline `AXI_SP32B1024`/`SP32B1024` yang benar (menunda flag `writting`/`reading` satu siklus tambahan) supaya bisa full posedge tanpa merusak fungsi. Proyek besar tersendiri, bukan quick-fix — jangan dicoba sebagai task kecil lagi.

---

## Cara kerja yang diharapkan

- **Selalu verifikasi sebelum klaim selesai ATAU sebelum klaim sesuatu itu "bug" — diff ke upstream untuk soal "sudah dipatch atau belum", simulasi fungsional untuk soal "ini bug atau desain sengaja".** Dua pelajaran nyata ada di item #7 "JANGAN DIRUSAK": satu soal patch yang diklaim selesai padahal tidak, satu lagi soal pola RTL yang diasumsikan bug padahal desain sengaja (dan asumsi keliru itu sempat datang dari rekomendasi eksternal, bukan dari source project sendiri).
- Compile firmware → cek `size`. Ubah RTL → `iverilog -g2012 -t null -s basys3_top <semua .v>` untuk elaborate check sebelum sintesis penuh. Untuk perubahan yang menyentuh timing/protokol (seperti percobaan negedge kemarin), buat **testbench fungsional** (bukan cuma elaborate check) sebelum menyimpulkan aman.
- **Sintesis itu lambat (~5-10 menit).** Untuk perubahan RTL, elaborate check dulu dengan iverilog sebelum `make synth`.
- **Simpan bitstream yang sudah bekerja** sebelum eksperimen berisiko. Board SRAM volatile — setelah power cycle harus `make flash` ulang.
- Setelah `make synth`, catat **Fmax (yang KEDUA/final, bukan yang pertama)** dan **utilisasi (LUT/FF/BRAM)** dari log — data ini dipakai untuk bab hasil skripsi. Simpan log lengkap (`2>&1 | tee synth_log.txt`), bukan cuma potongan akhir.
- Hanya pengguna yang punya board fisik. Claude tidak bisa verifikasi perilaku hardware — laporkan apa yang perlu diuji manual.
