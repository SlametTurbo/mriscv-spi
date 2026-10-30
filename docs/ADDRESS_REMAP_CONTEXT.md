# Konteks: Merapikan Peta Alamat AXI (mriscv @ Basys3)

Dokumen ini adalah konteks untuk agent yang akan menata ulang *address map* SoC mriscv
di repo ini (`~/mriscv-spi`). Snapshot per commit `a1bbb23` ("Added baud rate select for UART").
Detail lain (riwayat bug, cara flash, dsb.) ada di `CLAUDE.md` root repo — baca juga.

## Tujuan

Peta alamat sekarang tumbuh secara historis dan tidak punya pola. Targetnya pola SoC yang
umum: sebagian *bit* alamat menunjukkan nomor *slave*, sisanya *offset* register di dalam
*slave*. Contoh yang diinginkan user (dalam *byte address*): `0xABCDEFGH`, dengan *digit* `D`
= nomor *slave* dan `EFGH` = *offset* register.

Usulan konkret (silakan dikonfirmasi ke user sebelum eksekusi):

| Slave | Periferal | Byte address baru | Word address baru (`addr_use`) | `addr_mask` (word) |
|---|---|---|---|---|
| 0 | SRAM 32 KB | `0x0000_0000`–`0x0000_7FFF` | `0x0000_0000` | `0x1FFF` (tetap) |
| 1 | DAC | `0x0001_0000` | `0x0000_4000` | lihat "Pilihan mask" |
| 2 | ADC | `0x0002_0000` | `0x0000_8000` | 〃 |
| 3 | GPIO bank 1 | `0x0003_0000` | `0x0000_C000` | 〃 |
| 4 | SPI master iface (`spi_axi_slave`) | `0x0004_0000` | `0x0001_0000` | 〃 |
| 5 | UART | `0x0005_0000` | `0x0001_4000` | 〃 |
| 6 | GPIO bank 2 | `0x0006_0000` | `0x0001_8000` | 〃 |
| 7 | I2C master | `0x0007_0000` | `0x0001_C000` | 〃 |

Rumus: byte base = `n << 16`, word base = `n << 14`. Bonus: setiap base bisa dimuat dengan satu
instruksi `lui` (`lui t0, n<<4`), register diakses lewat *immediate offset*.

Catatan: dengan pola ini, slot 0 (SRAM) hanya boleh sampai 64 KB. SRAM sekarang 32 KB, jadi aman.

## Keadaan sekarang

`rtl/mriscv/mriscv_axi/impl_axi/impl_axi.v` (sekitar baris 80–93):

```verilog
localparam slaves = 8;
localparam [slaves*sword-1:0] addr_mask = {32'h00000003,32'h0000000F,32'h00000003,32'h00000000,32'h0000000F,32'h00000001,32'h00000001,32'h00001FFF};
localparam [slaves*sword-1:0] addr_use  = {32'h00004040,32'h00004030,32'h00004020,32'h04000000,32'h00004010,32'h00004008,32'h00004000,32'h00000000};
//                                         slave 7      slave 6      slave 5      slave 4      slave 3      slave 2      slave 1      slave 0
```

| Slave | Periferal | Word address | Byte address (dipakai firmware) |
|---|---|---|---|
| 0 | SRAM (`AXI_SP32B1024` + `SP32B1024`) | `0x0000`–`0x1FFF` | `0x00000`–`0x07FFF` |
| 1 | DAC (tidak dipakai) | `0x4000`–`0x4001` | `0x10000`–`0x10007` |
| 2 | ADC (tidak dipakai) | `0x4008`–`0x4009` | `0x10020`–`0x10027` |
| 3 | GPIO bank 1 (`completogpio`) | `0x4010`–`0x401F` | `0x10040 + 4*i` |
| 4 | `spi_axi_slave` (tidak dipakai) | `0x04000000` | `0x10000000` |
| 5 | UART (`uart.v`) | `0x4020`–`0x4023` | `0x10080`–`0x1008C` |
| 6 | GPIO bank 2 (`completogpio` #2) | `0x4030`–`0x403F` | `0x100C0 + 4*i` |
| 7 | I2C master (`i2c_master.v`) | `0x4040`–`0x4043` | `0x10100`–`0x1010C` |

Riwayat singkat: alamat asli repo mriscv adalah SRAM `0x000–0x3FF`, DAC `0x400`, ADC `0x408`,
GPIO `0x410`, SPI `0x04000000`. Saat SRAM diperbesar ke 32 KB, DAC/ADC/GPIO digeser ke `0x4000+`;
periferal baru lalu ditambahkan dengan jarak `0x10` *word*.

## Fakta RTL yang membatasi desain

1. **Interconnect bekerja dengan *word address*.** CPU mengeluarkan *byte address*, lalu
   `impl_axi.v` (~baris 246–247) menggesernya sebelum masuk interconnect:
   `assign m_axi_awaddr_o[0] = {2'b00, mriscvcore_awaddr[31:2]};` (sama untuk `araddr`).
   Semua `addr_use`/`addr_mask` dan semua *slave* melihat *word address*.
2. **Master 1 (`spi_axi_master`, *runtime loader*) mengirim *word address* apa adanya** dari
   frame SPI `{instr[1:0], addr[31:0], data[31:0]}` — tidak ada pergeseran. Jadi alamat di
   `tools/cheetah_mriscv.py` adalah *word address*.
3. **Decoder interconnect** (`axi4_interconnect/axi4_interconnect.v` ~baris 225–252):
   slave `i` terpilih bila `(addr & ~addr_mask[i]) == addr_use[i]`, lalu *priority encoder*
   (`priencr`). Implikasi:
   - `addr_mask` harus berbentuk `2^k − 1` dan `addr_use` harus *aligned* ke ukuran itu.
   - Perbandingan dilakukan pada semua 32 *bit* di luar mask → tidak ada *aliasing* di luar
     jendela slave.
   - Rentang slave tidak boleh tumpang tindih (priority encoder akan diam-diam memilih satu).
   - **Tidak ada DECERR.** Akses ke alamat yang tidak dipetakan menggantung bus sampai `RST`
     penuh (`BUS_RST` tidak cukup). Firmware yang hang tanpa trap → curigai alamat tak terpetakan.
   - Komentar asli menyebut decoder ini sebagai jalur gerbang terpanjang. Mask yang lebih lebar
     berarti lebih sedikit *bit* yang dibandingkan — tidak boleh memperburuk Fmax.
4. **Bit alamat yang dipakai tiap slave secara internal** (semuanya menerima *word address*
   penuh, bukan *offset*):
   - `AXI_SP32B1024.v`: `axi_awaddr[12:0]` / `axi_araddr[12:0]` (8192 word).
   - `completogpio.v` (via `latchW.v`): hanya `WAddres[2:0]` → pin 0–7. Mask sekarang `0xF`,
     jadi word `+8..+F` sudah *alias* ke pin 0–7.
   - `uart.v`, `i2c_master.v`: `ADDR[1:0]` → 4 register.
   - `DAC_interface_AXI`, `ADC_interface_AXI`, `spi_axi_slave`: mengabaikan alamat.
   Karena semua slave hanya memakai *bit* rendah, memindahkan base **tidak perlu mengubah
   modul slave** — cukup `addr_use`/`addr_mask`.
5. **SRAM harus tetap di alamat 0.** Linker `firmware/startup/link_c.ld` memakai
   `ORIGIN = 0x00000000, LENGTH = 32K` dan `_stack_top = ORIGIN + LENGTH`; loader memakai
   `SRAM_BASE = 0x000`.

## Pilihan mask (perlu diputuskan)

- **Mask penuh jendela** (`0x3FFF` word = 64 KB per slave): decoder hanya membandingkan
  *bit* `[31:14]` (lebih sederhana, kemungkinan lebih baik untuk Fmax), akses di dalam
  jendela tidak pernah menggantung bus, tetapi register akan ter-*alias* berulang di jendela.
  Pola ini umum di SoC kecil.
- **Mask ketat** (seperti sekarang: `0x3` untuk UART/I2C, `0xF` untuk GPIO, `0x1` DAC/ADC,
  `0x0` SPI): tidak ada *alias*, tetapi akses ke celah di dalam jendela menggantung bus
  karena tidak ada DECERR.

## Berkas yang memuat alamat dan harus diperbarui

RTL / testbench:
- `rtl/mriscv/mriscv_axi/impl_axi/impl_axi.v` — `addr_use`, `addr_mask`, komentar peta alamat.
- `rtl/mriscv/mriscv_axi/impl_axi/impl_axi_addrmap_tb.v` — tabel probe harapan ditulis
  **manual** (`p_addr[]`, `p_slv[]`, termasuk daftar alamat di luar peta). Program CPU di tb
  di-encode tangan (`lui` + `lw`), jadi immediate-nya ikut berubah. Cara jalan ada di header
  file (`iverilog -g2012 -s tb -o build/addrmap.vvp ...; vvp build/addrmap.vvp`). Saat ini 38/38 PASS.
- `rtl/mriscv/mriscv_axi/UART/uart.v`, `uart_tb.v` — hanya komentar yang menyebut `0x10080`.
- `rtl/basys3_top.v` — hanya komentar (`0x10040`, `0x100C0`).
- Testbench SoC lain di `impl_axi/` (`impl_axi_tb.v`, `impl_axi_busrst_tb.v`,
  `impl_axi_uartbaud_tb.v`, `impl_axi_uartrx_tb.v`, `basys3_top_*_tb.v`) — periksa apakah ada
  alamat hardcode atau bergantung pada firmware `.hex` yang harus di-*rebuild*.

Firmware:
- `firmware/include/mriscv.h` — `GPIO(i)` `0x10040`, `GPIO2(i)` `0x100C0`, `UART_*`
  `0x10080..0x1008C`, `I2C_*` `0x10100..0x1010C`. Sebaiknya diubah jadi `#define *_BASE` per slave.
- `firmware/apps/sevensegment.c`, `switch_led.c`, `switch_led_satu.c` — punya
  `#define GP(i)` sendiri dengan `0x10040`. Ganti ke makro dari `mriscv.h`.
- Cek ulang seluruh `firmware/` (apps, tests, probes) dengan grep alamat setelah perubahan.

Tools:
- `tools/cheetah_mriscv.py` — `GPIO_BASE = 0x4010` (word address, dipakai untuk menulis GPIO
  langsung lewat SPI). `SRAM_BASE` tetap 0.

Dokumentasi:
- `CLAUDE.md` — bagian "Peta alamat AXI", UART, I2C, GPIO, "Uji peta alamat".
- `README.md` bila menyebut alamat.

Abaikan: `rtl/mriscv/mriscv_apb/**` dan `rtl/mriscv/mriscvcore/firmware/**`,
`rtl/mriscv/mriscvcore/tests/**` (bawaan repo asli, tidak dipakai di alur ini), serta
`UART_TX/`, `UART_RX/` (modul lama, sudah tidak diinstansiasi).

## Verifikasi minimal

1. Unit tb slave tidak perlu diubah (slave hanya memakai *bit* rendah), tetapi tetap jalankan
   regresi `uart_tb.v` dan `i2c_master_tb.v`.
2. `impl_axi_addrmap_tb.v` dengan tabel baru: awal dan akhir tiap jendela memilih slave yang
   benar (one-hot `s_axi_awvalid`/`s_axi_arvalid`), plus beberapa alamat di luar peta tidak
   memilih slave mana pun.
3. Rebuild firmware lalu jalankan tb SoC: `impl_axi_uartbaud_tb` (firmware `uart_baud_test`),
   `impl_axi_uartrx_tb` (`uart_echo`), `impl_axi_busrst_tb`, `basys3_top_gpiobank_tb`,
   `basys3_top_i2c_tb`.
4. `make synth` → pastikan tidak ada regresi utilisasi dan **Fmax tetap ≥ 50 MHz**. Simpan log
   sintesis di `results/logs/`.
5. Uji di board: switch/LED/7-seg, encoder, OLED (bit-bang dan hardware I2C), UART echo dan
   ganti baud.

## Dampak ke naskah tesis (bukan tugas agent ini)

Repo tesis: `~/template_thesis_latex_dteti`. Setelah RTL final, yang perlu diperbarui:
Bab 3 Tabel 3.1 (*Address Map*, kolom *word* dan *byte address*), Tabel 3.2 (*Register Map*),
kalimat di sekitarnya, serta bagian Bab 4 yang menyebut alamat dan angka sintesis/Fmax.
