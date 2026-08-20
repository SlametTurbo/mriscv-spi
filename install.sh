#!/usr/bin/env bash
# =============================================================================
# install.sh -- setup TOTAL untuk mriscv-spi, dari toolchain kosong sampai siap
#               `make synth && make flash && make prog`.
#
# Menginstal (butuh sudo):
#   - RISC-V GCC       (gcc-riscv64-unknown-elf, apt)
#   - openFPGALoader   (apt, atau saran build-from-source bila tidak tersedia)
#   - openXC7 toolchain (yosys, nextpnr-xilinx, bbasm, fasm2frames,
#                        xc7frames2bit, bit2fasm) via paket .snap resmi
#
#     CATATAN PENTING: paket "openxc7" TIDAK terdaftar di Snap Store publik,
#     jadi `sudo snap install openxc7` akan gagal dgn "snap not found".
#     openXC7/toolchain-installer.sh (wrapper resmi lama) juga sudah TIDAK
#     ADA lagi di repo openXC7/toolchain-installer -- proyek itu kini
#     merekomendasikan Nix atau Apio sebagai cara instalasi utama.
#
#     Karena openXC7.mk di repo INI sudah mengasumsikan struktur
#     `/snap/openxc7/current/...` (dan sudah terbukti bekerja), skrip ini
#     TETAP memakai jalur snap -- tapi mengunduh file .snap LANGSUNG dari
#     GitHub Releases (openXC7/yosys-snap & openXC7/openXC7-snap) dan
#     memasangnya manual, mereplikasi persis logika wrapper resmi yang lama.
#     Versi per Agustus 2026: yosys v0.38, openxc7 0.8.2 (dicek masih
#     versi terbaru saat skrip ini ditulis). Jika suatu saat pemasangan
#     gagal karena versi ini sudah usang, cek versi terbaru di:
#       https://github.com/openXC7/yosys-snap/releases
#       https://github.com/openXC7/openXC7-snap/releases
#     lalu override: YOSYS_VER=x.xx OPENXC7_VER=x.x.x ./install.sh
#
# Menyiapkan struktur SIBLING yang diharapkan Makefile repo ini (variabel
# OPENXC7_MK default = ../openXC7.mk, CHIPDB default = ../chipdb/):
#   parent-dir/
#     openXC7.mk      <- disalin dari openXC7.mk yang sudah ada di repo ini
#     chipdb/         <- folder kosong, diisi otomatis saat `make synth` pertama
#     mriscv-spi/     <- repo ini (tempat install.sh dijalankan)
# =============================================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

YOSYS_VER="${YOSYS_VER:-0.38}"
OPENXC7_VER="${OPENXC7_VER:-0.8.2}"

echo "=== install.sh -- mriscv-spi ==="
echo "Repo   : $SCRIPT_DIR"
echo "Parent : $PARENT_DIR"
echo ""

# -----------------------------------------------------------------------------
# 1. Paket sistem dasar
# -----------------------------------------------------------------------------
echo "[1/5] Memasang paket dasar (build-essential, git, python3, snapd, wget, pypy3) ..."
sudo apt-get update -qq
sudo apt-get install -y build-essential git python3 python3-pip snapd wget pypy3 >/dev/null
echo "      selesai. (pypy3 dibutuhkan bbaexport.py saat generate chipdb -- bukan"
echo "      bagian dari paket snap openxc7, harus dipasang terpisah dari apt)"
echo ""

# -----------------------------------------------------------------------------
# 2. RISC-V GCC
# -----------------------------------------------------------------------------
echo "[2/5] Memasang RISC-V GCC (gcc-riscv64-unknown-elf) ..."
if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    echo "      [ok] sudah terpasang: $(riscv64-unknown-elf-gcc --version | head -1)"
else
    sudo apt-get install -y gcc-riscv64-unknown-elf
    echo "      [ok] terpasang."
fi
echo ""

# -----------------------------------------------------------------------------
# 3. openFPGALoader
# -----------------------------------------------------------------------------
echo "[3/5] Memasang openFPGALoader ..."
if command -v openFPGALoader >/dev/null 2>&1; then
    echo "      [ok] sudah terpasang."
elif sudo apt-get install -y openfpgaloader 2>/dev/null; then
    echo "      [ok] terpasang via apt."
else
    echo "      [!] tidak tersedia di repo apt distro ini."
    echo "          Build manual: https://github.com/trabucayre/openFPGALoader#install"
fi
echo ""

# -----------------------------------------------------------------------------
# 4. openXC7 toolchain -- unduh .snap langsung dari GitHub Releases
# -----------------------------------------------------------------------------
echo "[4/5] Memasang toolchain openXC7 (yosys v$YOSYS_VER + openxc7 $OPENXC7_VER) ..."
if [ -d /snap/openxc7 ] && command -v nextpnr-xilinx >/dev/null 2>&1; then
    echo "      [ok] openXC7 sudah terpasang."
else
    TMPD="$(mktemp -d)"
    cd "$TMPD"

    if ! command -v yosys >/dev/null 2>&1; then
        echo "      Mengunduh yosys_${YOSYS_VER}_amd64.snap ..."
        wget -q "https://github.com/openXC7/yosys-snap/releases/download/v${YOSYS_VER}/yosys_${YOSYS_VER}_amd64.snap"
        sudo snap install --classic --dangerous ./yosys_*.snap
        echo "      [ok] yosys terpasang."
    else
        echo "      [ok] yosys sudah terpasang, dilewati."
    fi

    if [ -d /snap/nextpnr-kintex ]; then
        echo "      Menghapus versi toolchain lama (nextpnr-kintex) ..."
        sudo snap remove nextpnr-kintex
    fi

    if [ -d /snap/openxc7 ]; then
        echo "      [!] /snap/openxc7 sudah ada tapi 'nextpnr-xilinx' tak dikenali PATH."
        echo "          Coba: sudo snap remove openxc7   lalu jalankan ulang install.sh"
    else
        echo "      Mengunduh openxc7_${OPENXC7_VER}_amd64.snap ..."
        wget -q "https://github.com/openXC7/openXC7-snap/releases/download/${OPENXC7_VER}/openxc7_${OPENXC7_VER}_amd64.snap"
        sudo snap install --classic --dangerous ./openxc7_*.snap
        echo "      [ok] openxc7 terpasang."
    fi

    # Alias agar tool bisa dipanggil langsung tanpa prefix "openxc7."
    for t in nextpnr-xilinx bbasm fasm2frames xc7frames2bit bit2fasm; do
        if ! command -v "$t" >/dev/null 2>&1; then
            sudo snap alias "openxc7.$t" "$t" 2>/dev/null || true
        fi
    done

    cd "$SCRIPT_DIR"
    rm -rf "$TMPD"
    echo "      [ok] openXC7 terpasang (yosys, nextpnr-xilinx, bbasm, fasm2frames,"
    echo "           xc7frames2bit, bit2fasm)."
fi
echo ""

# -----------------------------------------------------------------------------
# 5. Struktur sibling yang diharapkan Makefile (../openXC7.mk, ../chipdb/)
# -----------------------------------------------------------------------------
echo "[5/5] Menyiapkan struktur sibling (openXC7.mk & chipdb/ satu level di atas) ..."
if [ ! -f "$PARENT_DIR/openXC7.mk" ]; then
    if [ -f "$SCRIPT_DIR/openXC7.mk" ]; then
        cp "$SCRIPT_DIR/openXC7.mk" "$PARENT_DIR/openXC7.mk"
        echo "      [ok] $PARENT_DIR/openXC7.mk (disalin dari repo ini)"
    else
        echo "      [!] openXC7.mk tidak ditemukan di repo ini maupun di parent."
        echo "          Unduh manual dari https://github.com/openXC7/demo-projects"
    fi
else
    echo "      [ok] $PARENT_DIR/openXC7.mk sudah ada"
fi

mkdir -p "$PARENT_DIR/chipdb"
echo "      [ok] $PARENT_DIR/chipdb/ siap (diisi otomatis saat 'make synth' pertama)"
echo ""

# -----------------------------------------------------------------------------
# Ringkasan
# -----------------------------------------------------------------------------
echo "=== Ringkasan ==="
cd "$SCRIPT_DIR"
make check-tools
echo ""
echo "Jika semua [ok] di atas, lanjutkan:"
echo "  make synth XDC=basys3_spi.xdc && make flash && make prog FW=ledshow"
echo ""
echo "Catatan: jika tool masih [MISSING] padahal step [4/5] sukses, buka"
echo "terminal BARU (alias snap baru terbaca di sesi shell baru) atau"
echo "jalankan: hash -r"
