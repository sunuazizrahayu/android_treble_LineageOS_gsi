# LineageOS GSI Builder

Unofficial **LineageOS 23.2 GSI (Generic System Image, Android 16)** berbasis TrebleDroid — script dan manifest untuk build GSI `arm64 A/B` (varian vanilla & GApps, filesystem EROFS/ext4).

> Catatan: repo ini hanya berisi **script + manifest + dokumentasi**. Source Android (~200–300 GB) diunduh saat `repo sync` di mesin build, bukan di repo ini.

## Isi repo

| File | Fungsi |
|---|---|
| `manifest.xml` | Local manifest **minimal** TrebleDroid: `device/phh/treble`, `vendor/interfaces`, `hardware/oplus`, `vendor/hardware_overlay`, prebuilt VNDK v28. Disalin ke `.repo/local_manifests/` saat setup. Entri tambahan (GApps, VNDK v29/v30, dll) lihat bagian "Menambah entri manifest (opsional)". |
| `setup.sh` | Otomatisasi: `repo init` → pasang manifest → `repo sync` → terapkan patches. |
| `build.sh` | Build GSI per varian (vanilla/gapps × erofs/ext4). |
| `patches/` | (Opsional, bila ditambahkan nanti) patches lokal + `apply-patches.sh`. Selama belum ada, `setup.sh` memakai patches upstream `MisterZtr/LineageOS_gsi` sebagai fallback. |

## Kebutuhan mesin build

Build **tidak** bisa dilakukan di container kecil — siapkan mesin khusus:

- OS: Ubuntu 22.04 atau 24.04 (64-bit), fresh install disarankan
- CPU: 8 core+ (makin banyak makin cepat)
- RAM: 16 GB minimum (32 GB disarankan) + swap jika perlu
- Disk: **400 GB+ kosong** (source + ccache + output)
- Koneksi internet cepat & stabil (sync awal bisa puluhan GB)

Hasil build hanya untuk perangkat **ARM64 dengan partisi A/B** (`arm64-ab`). Bukan untuk `a-only` maupun `arm32`.

## 1. Pasang dependensi

```bash
sudo apt update
sudo apt install -y git git-lfs curl wget repo \
  bc bison build-essential ccache flex g++-multilib gcc-multilib \
  gnupg gperf imagemagick lib32ncurses-dev lib32readline-dev lib32z1-dev \
  libelf-dev liblz4-tool libncurses-dev libreadline-dev libsdl1.2-dev \
  libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
  squashfs-tools xsltproc zip zlib1g-dev python3 p7zip-full openjdk-17-jdk

# Tool repo (jika paket `repo` belum ada / terlalu lama):
mkdir -p ~/.bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
chmod +x ~/.bin/repo
echo 'export PATH=~/.bin:$PATH' >> ~/.bashrc && source ~/.bashrc
```

Aktifkan ccache (disarankan, mempercepat rebuild):

```bash
echo 'export USE_CCACHE=1' >> ~/.bashrc
echo 'export CCACHE_COMPRESS=1' >> ~/.bashrc
echo 'export CCACHE_MAXSIZE=50G' >> ~/.bashrc
source ~/.bashrc
```

Pastikan Java 17 sebagai default (dibutuhkan untuk build `treble_app`):

```bash
sudo update-alternatives --config java   # pilih java-17
java -version
```

## 2. Setup otomatis (disarankan)

```bash
git clone https://github.com/sunuazizrahayu/android_treble_LineageOS_gsi.git -b 23.2
cd android_treble_LineageOS_gsi
chmod +x setup.sh build.sh
./setup.sh ~/LineageOS     # argumen opsional, default: ~/LineageOS
```

`setup.sh` melakukan:

1. `repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs`
2. Menyalin `manifest.xml` repo ini → `<source>/.repo/local_manifests/manifest.xml`
3. `repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune`
4. Menerapkan patches (`patches/apply-patches.sh` bila repo ini sudah berisi `patches/`, jika belum memakai fallback upstream `MisterZtr/LineageOS_gsi:lineage-23.2`)

## 3. Setup manual (tanpa script)

```bash
mkdir LineageOS && cd LineageOS

# Init source LineageOS 23.2
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

# Pasang local manifest dari repo ini
mkdir -p .repo/local_manifests
curl -L https://raw.githubusercontent.com/sunuazizrahayu/android_treble_LineageOS_gsi/23.2/manifest.xml \
  -o .repo/local_manifests/manifest.xml

# Sync (lama, bisa berjam-jam)
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)

# Terapkan patches (salin manual dari checkout repo ini,
# atau fallback upstream bila repo ini belum berisi patches/):
git clone https://github.com/MisterZtr/LineageOS_gsi.git LineageOS_gsi -b lineage-23.2 --depth 1
bash LineageOS_gsi/patches/apply-patches.sh .
```

## 3a. Menambah entri manifest (opsional)

`manifest.xml` bawaan repo ini sengaja minimal (cukup untuk build vanilla).
Tambahkan blok berikut ke `.repo/local_manifests/manifest.xml` sesuai kebutuhan,
lalu `repo sync` ulang:

```xml
<manifest>
    <!-- ... isi minimal ... -->

    <!-- Wajib untuk varian GAPPS (bgN/bgNE) -->
    <remote name="gitlab" fetch="https://gitlab.com/" />
    <project path="vendor/gapps" remote="gitlab" name="MindTheGapps/vendor_gapps" revision="baklava" />

    <!-- Panel pengaturan Treble (GSI tetap boot tanpanya) -->
    <project path="treble_app" remote="github" name="TrebleDroid/treble_app" revision="master" />

    <!-- Sinyal di sebagian device Qualcomm -->
    <project path="packages/apps/QcRilAm" remote="github" name="AndyCGYan/android_packages_apps_QcRilAm" revision="master" />

    <!-- Perkakas phh -->
    <project path="vendor/vndk-tests" remote="github" name="phhusson/vendor_vndk-tests" revision="master" />
    <project path="vendor/lptools" remote="github" name="phhusson/vendor_lptools" revision="master" />
    <project path="vendor/magisk" remote="github" name="phhusson/vendor_magisk" revision="android-10.0" />

    <!-- Prebuilt VNDK Android 10/11 untuk kompatibilitas vendor lama -->
    <project path="prebuilts/vndk/v29" remote="aosp" name="platform/prebuilts/vndk/v29" clone-depth="1" revision="bef5d37dda9360940964f097d612c8032e140961" />
    <project path="prebuilts/vndk/v30" remote="aosp" name="platform/prebuilts/vndk/v30" clone-depth="1" revision="5f9884aa352825291757dfd6694b874ad8c1805e" />
</manifest>
```

## 4. Build

Jalankan dari **root source tree** (`~/LineageOS`):

```bash
cd ~/LineageOS
```

| Varian | Filesystem | Perintah |
|---|---|---|
| VANILLA | EROFS | `bash LineageOS_gsi/build.sh --variant vanilla --fs erofs` |
| VANILLA | ext4 | `bash LineageOS_gsi/build.sh --variant vanilla --fs ext4` |
| GAPPS | EROFS | `bash LineageOS_gsi/build.sh --variant gapps --fs erofs` |
| GAPPS | ext4 | `bash LineageOS_gsi/build.sh --variant gapps --fs ext4` |

Setara manual (contoh VANILLA EROFS):

```bash
. build/envsetup.sh
ccache -M 50G -F 0
breakfast lineage_arm64_bvNE-bp4a-userdebug
make systemimage -j$(nproc --all)
```

Nama lunch target lengkap:

- VANILLA EROFS: `lineage_arm64_bvNE-bp4a-userdebug`
- VANILLA ext4: `lineage_arm64_bvN4-bp4a-userdebug`
- GAPPS EROFS: `lineage_arm64_bgNE-bp4a-userdebug`
- GAPPS ext4: `lineage_arm64_bgN4-bp4a-userdebug`

Hasil build:

```text
out/target/product/tdgsi_arm64_ab/system.img
```

`bvN` = vanilla (tanpa GApps), `bgN` = dengan GApps (MindTheGapps). EROFS butuh kernel 5.4+ di perangkat; bila ragu/bootloop, pakai varian ext4 (read-write penuh).

## 5. Kompres hasil (opsional)

```bash
cd out/target/product/tdgsi_arm64_ab
7z a system.img.xz system.img
```

## 6. Sync ulang / rebuild

```bash
cd ~/LineageOS
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)
bash LineageOS_gsi/patches/apply-patches.sh .   # ulangi setelah sync bila ada update
bash LineageOS_gsi/build.sh --variant vanilla --fs erofs
```

## Troubleshooting

- **`repo: command not found`** → pasang tool `repo` seperti di bagian dependensi, pastikan `~/.bin` ada di `PATH`.
- **Gagal apply patch / konflik** → patch harus diterapkan manual satu per satu (`git apply --check`, `git am`), biasanya karena source upstream berubah. Sinkronkan ulang patches dengan upstream `MisterZtr/LineageOS_gsi`.
- **Build OOM / killed** → kurangi jobs (`--jobs 4`), tambah RAM/swap.
- **Disk penuh** → butuh 400 GB+; bersihkan dengan `make clean` atau hapus `out/` bila ingin build ulang penuh.
- **Bootloop di HP, EROFS** → coba varian ext4; pastikan perangkat `arm64 A/B` dan vendor Android yang kompatibel.

## Kredit

- [LineageOS Team](https://github.com/LineageOS)
- [Phhusson](https://github.com/phhusson) dan [TrebleDroid](https://github.com/TrebleDroid)
- [AndyYan](https://github.com/AndyCGYan)
- [MisterZtr](https://github.com/MisterZtr/LineageOS_gsi) — referensi script, patches & manifest lineage-23.2
- [Ponces](https://github.com/ponces), [Peter Cai](https://github.com/PeterCxy), [Iceows](https://github.com/Iceows), [ChonDoit](https://github.com/ChonDoit), [Nazim N](https://github.com/naz664), [Ahnet](https://github.com/ahnet-69), [mytja](https://github.com/mytja), [cawilliamson](https://github.com/cawilliamson), [Doze-off](https://github.com/Doze-off)
