#!/bin/bash
# setup.sh - Siapkan source tree LineageOS 23.2 untuk build GSI (TrebleDroid).
# Jalankan dari MESIN BUILD (Ubuntu 22.04/24.04, RAM 16GB+, disk kosong 400GB+),
# BUKAN di container kecil. Lihat README.md untuk prasyarat lengkap.
#
#   ./setup.sh [SOURCE_DIR] [--lineage]
#
# Contoh:
#   ./setup.sh ~/LineageOS              # jalur treble (patches/ repo ini)
#   ./setup.sh ~/LineageOS --lineage   # jalur lineage (patches lineage kurasi)
#
# Dua jalur ini SALING LEPAS, jangan campur patches-nya:
# - treble   : manifest.xml + patches/ lokal, lalu generate.sh + lunch treble_*
# - lineage  : manifest-lineage.xml + patches/lineage kurasi, lalu lunch lineage_*
#   (tanpa generate.sh - definisi product lineage_* datang dari patches)
#
# Langkah yang dilakukan (mode treble):
#   1. Cek tool wajib (git, curl, repo)
#   2. repo init LineageOS/android -b lineage-23.2
#   3. Pasang manifest repo ini ke .repo/local_manifests/
#   4. repo sync
#   5. Terapkan patches
#   6. Generate definisi product TrebleDroid (device/phh/treble/generate.sh)

set -euo pipefail

SOURCE_DIR="$HOME/LineageOS"
LINEAGE=0
for arg in "$@"; do
  case "$arg" in
    --lineage) LINEAGE=1 ;;
    -h|--help)
      echo "Pakai: $0 [SOURCE_DIR] [--lineage]"
      echo "  SOURCE_DIR  folder source tree (default: \$HOME/LineageOS)"
      echo "  --lineage  jalur lineage (patches/lineage kurasi)"
      exit 0 ;;
    *) SOURCE_DIR="$arg" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$LINEAGE" -eq 1 ]; then
  MANIFEST_SRC="$SCRIPT_DIR/manifest-lineage.xml"
else
  MANIFEST_SRC="$SCRIPT_DIR/manifest.xml"
fi
LINEAGE_BRANCH="lineage-23.2"
JOBS="$(nproc --all 2>/dev/null || echo 4)"

echo "=== LineageOS 23.2 GSI setup ==="
echo "Source dir : $SOURCE_DIR"
echo "Branch     : $LINEAGE_BRANCH"
echo ""

# 1. Cek tool wajib
for cmd in git curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' belum terinstal. Ikuti bagian 'Dependensi' di README.md." >&2
    exit 1
  fi
done

if ! command -v repo >/dev/null 2>&1; then
  echo "ERROR: 'repo' belum terinstal."
  echo "Pasang dengan: mkdir -p ~/.bin && curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo && chmod +x ~/.bin/repo"
  echo "Lalu tambahkan ~/.bin ke PATH." >&2
  exit 1
fi

if [ ! -f "$MANIFEST_SRC" ]; then
  echo "ERROR: manifest.xml tidak ditemukan di $SCRIPT_DIR" >&2
  exit 1
fi

# 2. repo init
mkdir -p "$SOURCE_DIR"
cd "$SOURCE_DIR"

if [ ! -d ".repo" ]; then
  echo "--- repo init ---"
  repo init -u https://github.com/LineageOS/android.git -b "$LINEAGE_BRANCH" --git-lfs
else
  echo "--- .repo sudah ada, lewati repo init ---"
fi

# 3. Pasang local manifest
echo "--- pasang local manifest ---"
mkdir -p .repo/local_manifests
cp -f "$MANIFEST_SRC" .repo/local_manifests/manifest.xml
echo "manifest.xml -> .repo/local_manifests/manifest.xml"

# 4. repo sync
echo "--- repo sync (ini lama, bisa berjam-jam) ---"
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j"$JOBS"

# 5. Terapkan patches
echo "--- terapkan patches ---"
if [ "$LINEAGE" -eq 1 ]; then
  # Jalur lineage: HANYA patches/lineage kurasi, jangan campur patches treble.
  bash "$SCRIPT_DIR/patches/apply-patches.sh" --lineage
elif [ -f "$SCRIPT_DIR/patches/apply-patches.sh" ]; then
  # setup.sh dijalankan dari checkout repo ini di luar source tree:
  # salin patches lokal ke dalam source tree
  mkdir -p LineageOS_gsi
  cp -r "$SCRIPT_DIR/patches" LineageOS_gsi/
  cp -f "$SCRIPT_DIR/manifest.xml" LineageOS_gsi/ 2>/dev/null || true
  bash LineageOS_gsi/patches/apply-patches.sh .
else
  echo "ERROR: patches/apply-patches.sh tidak ditemukan di $SCRIPT_DIR." >&2
  echo "Clone repo ini lengkap (bukan partial/sparse tanpa patches/)." >&2
  exit 1
fi

# 6. Generate definisi product TrebleDroid (hanya jalur treble).
# Jalur lineage dilewati: definisi product lineage_* datang dari patches.
if [ "$LINEAGE" -eq 0 ]; then
  echo "--- generate treble products ---"
  (cd device/phh/treble && bash generate.sh)
  ls device/phh/treble/treble_arm64_bvN.mk device/phh/treble/AndroidProducts.mk
fi

echo ""
echo "=== Setup selesai ==="
if [ "$LINEAGE" -eq 1 ]; then
  echo "Lanjut ke build Lineage, contoh (VANILLA ext4):"
  echo "  cd $SOURCE_DIR"
  echo "  . build/envsetup.sh"
  echo "  breakfast lineage_arm64_bvN4-bp4a-userdebug"
  echo "  make systemimage -j\$(nproc --all)"
else
  echo "Lanjut ke build treble:"
  echo "  cd $SOURCE_DIR"
  echo "  . build/envsetup.sh"
  echo "  lunch treble_arm64_bvN-bp4a-userdebug"
  echo "  make systemimage -j\$(nproc --all) DISABLE_DEXPREOPT_CHECK=true"
fi
