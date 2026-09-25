#!/bin/bash
# build.sh - Build LineageOS 23.2 GSI (TrebleDroid).
# Jalankan dari ROOT source tree (folder yang berisi build/envsetup.sh).
#
#   build.sh [--variant vanilla|gapps] [--fs erofs|ext4] [--jobs N] [--no-ccache]
#
# Varian (mengikuti pola MisterZtr/LineageOS_gsi):
#   vanilla + erofs -> lineage_arm64_bvNE-bp4a-userdebug
#   vanilla + ext4  -> lineage_arm64_bvN4-bp4a-userdebug
#   gapps   + erofs -> lineage_arm64_bgNE-bp4a-userdebug
#   gapps   + ext4  -> lineage_arm64_bgN4-bp4a-userdebug
#
# Contoh:
#   ./LineageOS_gsi/build.sh --variant vanilla --fs erofs
#   ./LineageOS_gsi/build.sh --variant gapps --fs ext4 --jobs 8
#
# Hasil: out/target/product/tdgsi_arm64_ab/system.img

set -euo pipefail

VARIANT="vanilla"
FS="erofs"
JOBS="$(nproc --all 2>/dev/null || echo 4)"
USE_CCACHE=1

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  echo "Opsi:"
  echo "  --variant vanilla|gapps   (default: vanilla)"
  echo "  --fs erofs|ext4           (default: erofs)"
  echo "  --jobs N                  (default: nproc = $JOBS)"
  echo "  --no-ccache               nonaktifkan ccache untuk build ini"
  echo "  --help                    tampilkan bantuan ini"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --variant) VARIANT="${2:-}"; shift 2 ;;
    --fs) FS="${2:-}"; shift 2 ;;
    --jobs|-j) JOBS="${2:-}"; shift 2 ;;
    --no-ccache) USE_CCACHE=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Argumen tidak dikenal: $1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$VARIANT" in
  vanilla) PREFIX="bvN" ;;
  gapps) PREFIX="bgN" ;;
  *) echo "ERROR: --variant harus vanilla|gapps (dapat: $VARIANT)" >&2; exit 1 ;;
esac

case "$FS" in
  erofs) SUFFIX="E" ;;
  ext4) SUFFIX="4" ;;
  *) echo "ERROR: --fs harus erofs|ext4 (dapat: $FS)" >&2; exit 1 ;;
esac

LUNCH="lineage_arm64_${PREFIX}${SUFFIX}-bp4a-userdebug"

if [ ! -f "build/envsetup.sh" ]; then
  echo "ERROR: build/envsetup.sh tidak ditemukan." >&2
  echo "Jalankan script ini dari ROOT source tree LineageOS (hasil setup.sh)." >&2
  exit 1
fi

if [ "$VARIANT" = "gapps" ] && [ ! -d "vendor/gapps" ]; then
  echo "ERROR: vendor/gapps belum tersync (manifest minimal hanya untuk vanilla)." >&2
  echo "Tambahkan entri vendor/gapps ke .repo/local_manifests/manifest.xml lalu repo sync." >&2
  echo "Lihat README.md bagian 'Menambah entri manifest (opsional)'." >&2
  exit 1
fi

echo "=== LineageOS 23.2 GSI build ==="
echo "Varian : $VARIANT ($LUNCH)"
echo "FS     : $FS"
echo "Jobs   : $JOBS"
echo ""

# ccache (disarankan untuk rebuild)
if [ "$USE_CCACHE" -eq 1 ]; then
  export USE_CCACHE=1
  export CCACHE_COMPRESS=1
  export CCACHE_MAXSIZE=50G
fi

# shellcheck disable=SC1091
. build/envsetup.sh

if [ "$USE_CCACHE" -eq 1 ] && command -v ccache >/dev/null 2>&1; then
  ccache -M 50G -F 0 || true
fi

breakfast "$LUNCH"
make systemimage -j"$JOBS"

echo ""
echo "=== Build selesai ==="
echo "Output: out/target/product/tdgsi_arm64_ab/system.img"
echo "Kompres (opsional): cd out/target/product/tdgsi_arm64_ab && 7z a system.img.xz system.img"
