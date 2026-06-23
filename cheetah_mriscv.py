#!/usr/bin/env python3
# ============================================================================
# cheetah_mriscv.py - Host uploader untuk mriscv via Total Phase Cheetah (Ubuntu)
#
# Mengirim frame SPI 66-bit {instr[1:0], addr[31:0], data[31:0]} ke spi_axi_master
# (versi single-clock) untuk:
#   - upload program ke BRAM lalu melepas core, atau
#   - memprogram GPIO langsung (core boleh tetap di-reset).
#
# Protokol & pengemasan byte SUDAH diverifikasi terhadap RTL di simulasi:
#   * SPI mode 0 (CPOL=0, CPHA=0), MSB-first, CS (CEB) aktif-rendah.
#   * Frame 66-bit dikemas ke 9 byte (72 bit), left-aligned, 6 bit padding 0 di akhir
#     (padding dibuang hardware saat CS naik).
#   * Syarat: SCLK <= ~CLK/4. Dengan core /64 (~1.5 MHz) -> pakai SCLK <= ~200 kHz.
#
# Wiring Cheetah -> Pmod JA Basys3:
#   SCLK -> JA1 (J1),  MOSI -> JA2 (L2),  SS0/CS -> JA3 (J2),  GND -> GND Pmod.
#   (MISO/JA4 tidak dipakai; loader ini write-only.)
#
# Pakai:
#   python3 cheetah_mriscv.py upload prog.bin                 # upload + jalankan
#   python3 cheetah_mriscv.py upload firmware.hex --no-release
#   python3 cheetah_mriscv.py gpio 0 on                       # LED0 nyala
#   python3 cheetah_mriscv.py gpio 3 off
#   python3 cheetah_mriscv.py release                         # lepas core saja
#   tambahkan --dry-run untuk melihat frame tanpa perangkat
# ============================================================================
import sys, argparse, struct
from array import array

# --- konstanta protokol ---
INSTR_WRITE = 0b10
INSTR_NOP   = 0b00
SRAM_BASE   = 0x000          # word-address RAM (program) 0x000..0x3FF
GPIO_BASE   = 0x410          # word-address GPIO pin 0; pin i -> 0x410 + i
GPIO_ON     = 0x3            # data=1, DSE(enable)=1
GPIO_OFF    = 0x2            # data=0, DSE(enable)=1
FRAME_BYTES = 9              # 66 bit -> 9 byte (72 bit) dgn padding

# --- konfigurasi Cheetah (mode 0) ---
DEFAULT_PORT    = 0
DEFAULT_BITRATE = 100        # kHz (aman utk core /64; naikkan hanya bila CLK dinaikkan)


def frame_bytes(instr, addr, data):
    """Kemas frame 66-bit -> 9 byte, MSB-first, left-aligned (6 bit pad di akhir)."""
    frame = ((instr & 0x3) << 64) | ((addr & 0xFFFFFFFF) << 32) | (data & 0xFFFFFFFF)
    f72 = frame << 6
    return bytes((f72 >> (8 * (8 - i))) & 0xFF for i in range(9))


def load_words(path):
    """Baca program: .hex (satu kata hex per baris) atau .bin (raw little-endian)."""
    if path.endswith(".hex"):
        words = []
        for line in open(path):
            line = line.strip()
            if line:
                words.append(int(line, 16) & 0xFFFFFFFF)
        return words
    data = open(path, "rb").read()
    data += b"\x00" * ((-len(data)) % 4)              # pad ke kelipatan 4
    return [struct.unpack("<I", data[i:i + 4])[0] for i in range(0, len(data), 4)]


# ============================ backend Cheetah ===============================
class CheetahLink:
    def __init__(self, port, bitrate_khz):
        try:
            import cheetah_py as ch
        except ImportError:
            sys.exit(
                "ERROR: modul 'cheetah_py' tidak ditemukan.\n"
                "Pasang Cheetah SDK (lihat README_CHEETAH.md): letakkan cheetah_py.py "
                "dan cheetah.so di folder ini atau pada PYTHONPATH/LD_LIBRARY_PATH."
            )
        self.ch = ch
        h = ch.ch_open(port)
        if h <= 0:
            sys.exit("ERROR: gagal membuka Cheetah port %d (kode %d). "
                     "Cek koneksi USB / izin (udev) / port." % (port, h))
        self.h = h
        # Mode 0: clock idle rendah (RISING_FALLING) + sample di tepi depan (SAMPLE_SETUP)
        ch.ch_spi_configure(h, ch.CH_SPI_POL_RISING_FALLING,
                            ch.CH_SPI_PHASE_SAMPLE_SETUP,
                            ch.CH_SPI_BITORDER_MSB, 0x0)   # ss_polarity=0 -> SS aktif-rendah
        actual = ch.ch_spi_bitrate(h, bitrate_khz)
        print("Cheetah terbuka (port %d), SCLK = %d kHz, mode 0, MSB-first." % (port, actual))

    def send_frame(self, instr, addr, data):
        ch, h = self.ch, self.h
        payload = array('B', frame_bytes(instr, addr, data))
        ch.ch_spi_queue_clear(h)
        ch.ch_spi_queue_oe(h, 1)
        ch.ch_spi_queue_ss(h, 0x1)        # assert SS0 (CS -> rendah)
        ch.ch_spi_queue_array(h, payload)
        ch.ch_spi_queue_ss(h, 0x0)        # deassert SS0 (CS -> tinggi; buang 6 bit pad)
        ch.ch_spi_batch_shift(h, len(payload))

    def close(self):
        self.ch.ch_close(self.h)


class DryRun:
    """Backend palsu: cetak frame, tidak butuh perangkat/SDK."""
    def __init__(self, *a, **k):
        print("[dry-run] tidak membuka perangkat; hanya mencetak frame.")
    def send_frame(self, instr, addr, data):
        b = frame_bytes(instr, addr, data)
        names = {INSTR_WRITE: "WRITE", INSTR_NOP: "NOP  "}
        print("  %s addr=0x%08X data=0x%08X  -> bytes %s"
              % (names.get(instr, "?"), addr, data, b.hex()))
    def close(self):
        pass


# ============================ operasi tingkat-atas ===========================
def do_upload(link, path, release=True):
    words = load_words(path)
    print("Upload %d kata dari %s ..." % (len(words), path))
    link.send_frame(INSTR_NOP, 0, 0)                       # pastikan PICORV_RST=0 (core ditahan)
    for i, w in enumerate(words):
        link.send_frame(INSTR_WRITE, SRAM_BASE + i, w)
    if release:
        link.send_frame(INSTR_NOP, 0, 1)                   # bit terakhir=1 -> lepas core
        print("Selesai. Core dilepas; program berjalan.")
    else:
        print("Selesai. Core MASIH ditahan reset (pakai 'release' utk menjalankan).")


def do_gpio(link, pin, on):
    if not (0 <= pin <= 7):
        sys.exit("ERROR: pin GPIO harus 0..7")
    link.send_frame(INSTR_WRITE, GPIO_BASE + pin, GPIO_ON if on else GPIO_OFF)
    print("GPIO pin %d -> %s" % (pin, "ON" if on else "OFF"))


def do_release(link):
    link.send_frame(INSTR_NOP, 0, 1)
    print("Core dilepas (PICORV_RST=1).")


def main():
    ap = argparse.ArgumentParser(description="Host uploader mriscv via Cheetah SPI")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--bitrate", type=int, default=DEFAULT_BITRATE, help="SCLK kHz (<= ~200)")
    ap.add_argument("--dry-run", action="store_true", help="cetak frame tanpa perangkat")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_up = sub.add_parser("upload", help="upload program (.bin/.hex) lalu jalankan")
    p_up.add_argument("file")
    p_up.add_argument("--no-release", action="store_true", help="jangan lepas core")

    p_gp = sub.add_parser("gpio", help="set GPIO pin")
    p_gp.add_argument("pin", type=int)
    p_gp.add_argument("state", choices=["on", "off"])

    sub.add_parser("release", help="lepas core (PICORV_RST=1)")

    args = ap.parse_args()
    Backend = DryRun if args.dry_run else CheetahLink
    link = Backend(args.port, args.bitrate)
    try:
        if args.cmd == "upload":
            do_upload(link, args.file, release=not args.no_release)
        elif args.cmd == "gpio":
            do_gpio(link, args.pin, args.state == "on")
        elif args.cmd == "release":
            do_release(link)
    finally:
        link.close()


if __name__ == "__main__":
    main()
