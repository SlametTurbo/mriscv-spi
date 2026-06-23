#!/usr/bin/env python3
# ============================================================================
# cheetah_loopback.py - Uji loopback Cheetah SPI (tanpa FPGA)
#
# Sambungkan MOSI <-> MISO Cheetah dengan kabel, lalu jalankan:
#     python3 cheetah_loopback.py
#
# Jika Cheetah + SDK + USB sehat, byte yang dikirim akan terbaca kembali identik.
#   TX == RX  -> Cheetah OK (masalah ada di FPGA/wiring ke papan)
#   TX != RX  -> masalah di Cheetah/SDK/USB/kabel loopback
# ============================================================================
import sys
from array import array

def main():
    try:
        import cheetah_py as ch
    except ImportError:
        sys.exit("ERROR: modul 'cheetah_py' tidak ditemukan. Pasang Cheetah SDK "
                 "(cheetah_py.py + cheetah.so) di folder ini atau PYTHONPATH/LD_LIBRARY_PATH.")

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    h = ch.ch_open(port)
    if h <= 0:
        sys.exit("ERROR: gagal membuka Cheetah port %d (kode %d)." % (port, h))

    # Mode 0, MSB-first, SS aktif-rendah, 100 kHz (sama dgn uploader)
    ch.ch_spi_configure(h, ch.CH_SPI_POL_RISING_FALLING,
                        ch.CH_SPI_PHASE_SAMPLE_SETUP,
                        ch.CH_SPI_BITORDER_MSB, 0x0)
    rate = ch.ch_spi_bitrate(h, 100)
    print("Cheetah port %d terbuka, %d kHz. Mengirim pola uji..." % (port, rate))

    tx = array('B', [0x00, 0xFF, 0xA5, 0x5A, 0xAB, 0xCD, 0x01, 0x80])
    ch.ch_spi_queue_clear(h)
    ch.ch_spi_queue_oe(h, 1)
    ch.ch_spi_queue_ss(h, 0x1)
    ch.ch_spi_queue_array(h, tx)
    ch.ch_spi_queue_ss(h, 0x0)
    ret = ch.ch_spi_batch_shift(h, len(tx))

    # ch_spi_batch_shift mengembalikan (count, data_in) pd sebagian besar binding
    if isinstance(ret, tuple):
        count, rx = ret
    else:
        count, rx = ret, array('B', [])
    ch.ch_close(h)

    tx_hex = ' '.join('%02X' % b for b in tx)
    rx_hex = ' '.join('%02X' % b for b in rx) if len(rx) else "(kosong)"
    print("TX: %s" % tx_hex)
    print("RX: %s" % rx_hex)

    if len(rx) >= len(tx) and all(rx[i] == tx[i] for i in range(len(tx))):
        print(">>> LOOPBACK OK: Cheetah mengirim & membaca dengan benar.")
        print("    (Jika upload ke FPGA tetap gagal, masalah ada di bitstream/wiring papan.)")
    else:
        print("!!! LOOPBACK GAGAL: TX != RX.")
        print("    Cek: kabel MOSI<->MISO tersambung? port Cheetah benar? SDK benar?")

if __name__ == "__main__":
    main()
