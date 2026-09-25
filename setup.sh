#!/bin/bash
# setup.sh - Siapkan source tree LineageOS 23.2 untuk build GSI (TrebleDroid).
# Jalankan dari MESIN BUILD (Ubuntu 22.04/24.04, RAM 16GB+, disk kosong 400GB+),
# BUKAN di container kecil. Lihat README.md untuk prasyarat lengkap.
#
#   ./setup.sh [SOURCE_DIR]
#
# Contoh:
#   ./setup.sh ~/LineageOS
#
# Langkah yang dilakukan:
#   1. Cek tool wajib (git, curl, repo)
#   2. repo init LineageOS/android -b lineage-23.2
#   3. Pasang manifest.xml repo ini ke .repo/local_manifests/
#   4. repo sync
#   5. Terapkan patches (patches/apply-patches.sh bila ada,
#      fallback ke MisterZtr/LineageOS_gsi upstream)

set -euo pipefail

SOURCE_DIR="${1:-$HOME/LineageOS}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_SRC="$SCRIPT_DIR/manifest.xml"
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
if [ -f "$SCRIPT_DIR/patches/apply-patches.sh" ]; then
  # setup.sh dijalankan dari checkout repo ini di luar source tree:
  # salin patches lokal ke dalam source tree
  mkdir -p LineageOS_gsi
  cp -r "$SCRIPT_DIR/patches" LineageOS_gsi/
  cp -f "$SCRIPT_DIR/manifest.xml" LineageOS_gsi/ 2>/dev/null || true
  bash LineageOS_gsi/patches/apply-patches.sh .
else
  echo "Repo ini belum berisi patches/. Mengambil patches upstream (MisterZtr/LineageOS_gsi) sebagai fallback..."
  if [ ! -d "LineageOS_gsi/.git" ]; then
    git clone https://github.com/MisterZtr/LineageOS_gsi.git LineageOS_gsi -b lineage-23.2 --depth 1
  else
    git -C LineageOS_gsi fetch origin lineage-23.2 --depth 1
    git -C LineageOS_gsi checkout -f origin/lineage-23.2
  fi
  bash LineageOS_gsi/patches/apply-patches.sh .
fi

echo ""
echo "=== Setup selesai ==="
echo "Lanjut ke build, contoh (VANILLA erofs):"
echo "  cd $SOURCE_DIR && bash LineageOS_gsi/build.sh --variant vanilla --fs erofs"
echo "Atau jika repo ini di-checkout terpisah: bash $SCRIPT_DIR/build.sh --variant vanilla --fs erofs"
echo "Detail semua varian ada di README.md dan 'build.sh --help'."
