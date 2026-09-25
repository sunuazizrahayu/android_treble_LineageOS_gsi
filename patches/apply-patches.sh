#!/bin/bash
# apply-patches.sh - Terapkan patches repo ini ke source tree Android.
# Jalankan dari ROOT source tree (folder yang berisi build/envsetup.sh):
#
#   bash <path-ke-repo-ini>/patches/apply-patches.sh
#
# Contoh bila repo ini di-clone di samping source tree:
#   cd ~/LineageOS_gsi && bash ~/android_treble_LineageOS_gsi/patches/apply-patches.sh
#
# Contoh bila folder repo ini disalin ke dalam source tree sebagai LineageOS_gsi/:
#   cd ~/LineageOS_gsi && bash LineageOS_gsi/patches/apply-patches.sh
#
# Struktur patches: patches/<grup>/<nama_dir_dengan_underscore>/*.patch
# Contoh: patches/personal/device_phh_treble/*.patch diterapkan di device/phh/treble.
#
# Script ini idempotent: aman dijalankan berulang kali. Patch yang sudah
# kepasang terdeteksi dan di-skip (bukan error).

set -e

PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ambil subject patch persis seperti yang dicatat git am (satu baris).
# Syarat: Subject di file patch harus SATU BARIS (tanpa continuation).
# Mendukung varian prefix: [PATCH], [PATCH 02/10], [PATCH v2], dsb.
# (git am membuang bagian [...] itu, jadi harus dibuang di sini juga
# agar cocok dengan `git log --format=%s`.)
patch_subject() {
    sed -n 's/^Subject: \[PATCH[^]]*\] *//p' "$1" | head -1
}

# True bila commit dengan subject tersebut sudah ada di repo ini.
patch_committed() {
    local subject
    subject="$(patch_subject "$1")"
    [ -n "$subject" ] && git log --format=%s 2>/dev/null | grep -qxF -m1 -- "$subject"
}

apply_patch_dir() {
    local patch_dir=$1
    local patch_name=$2

    printf "\n ### APPLYING %s PATCHES ###\n" "$patch_name"
    sleep 1.0

    if [ ! -d "$patch_dir" ]; then
        printf "Directory %s not found, skipping...\n" "$patch_dir"
        return 0
    fi

    for path in $(cd "$patch_dir"; echo *); do
        tree="$(tr _ / <<<"$path" | sed -e 's;platform/;;g')"
        printf "\n| %s ###\n" "$path"

        [ "$tree" == build ] && tree=build/make
        [ "$tree" == testing ] && tree=platform_testing
        [ "$tree" == vendor/hardware/overlay ] && tree=vendor/hardware_overlay
        [ "$tree" == treble/app ] && tree=treble_app
        [ "$tree" == vendor/partner/gms ] && tree=vendor/partner_gms

        if [ ! -d "$tree" ]; then
            printf "Tree %s not found, skipping %s...\n" "$tree" "$path"
            continue
        fi

        pushd "$tree" > /dev/null

        for patch in "$patch_dir"/"$path"/*.patch; do
            if patch_committed "$patch"; then
                printf "### already applied, skipping: %s\n" "$(basename "$patch")"
            elif git apply --check "$patch" > /dev/null 2>&1; then
                if git am "$patch" > /dev/null 2>&1; then
                    printf "### applied: %s\n" "$(basename "$patch")"
                else
                    git am --abort > /dev/null 2>&1 || true
                    printf "### FAILED APPLYING: %s \n" "$patch"
                fi
            elif git apply --check -R "$patch" > /dev/null 2>&1; then
                printf "### already applied, skipping: %s\n" "$(basename "$patch")"
            elif patch -f -p1 --dry-run < "$patch" > /dev/null 2>&1; then
                git am "$patch" > /dev/null 2>&1 || true
                patch -f -p1 < "$patch"
                git add -u
                git am --continue > /dev/null 2>&1 || true
            else
                printf "### FAILED APPLYING: %s \n" "$patch"
            fi
        done

        popd > /dev/null
    done
}

apply_patch_dir "$PATCHES_DIR/personal" "PERSONAL"
