# LineageOS GSI Builder

Unofficial **LineageOS 23.2 GSI (Generic System Image, Android 16)** berbasis TrebleDroid — script dan manifest untuk build GSI `arm64 A/B` (varian vanilla & GApps, filesystem EROFS/ext4).

> Catatan: repo ini hanya berisi **script + manifest + dokumentasi**. Source Android (~200–300 GB) diunduh saat `repo sync` di mesin build, bukan di repo ini.

## Isi repo

| File | Fungsi |
|---|---|
| `manifest.xml` | Local manifest **minimal** TrebleDroid: `device/phh/treble`, `vendor/interfaces`, `hardware/oplus`, `vendor/hardware_overlay`, prebuilt VNDK v28/v29. Disalin ke `.repo/local_manifests/` saat setup. Contoh entri GApps ada di komentar atas file-nya. |
| `manifest-lineage.xml` | Local manifest **lengkap** untuk jalur Lineage (patches lineage kurasi): treble_app, QcRilAm, perkakas phh, overlay fork MisterZtr, VNDK v28–v30, GApps. Dipakai via `./setup.sh DIR --lineage`. Jangan campur dengan patches treble. |
| `setup.sh` | Otomatisasi: `repo init` → pasang manifest → `repo sync` → terapkan patches. |
| `build.sh` | Build GSI per varian (vanilla/gapps × erofs/ext4). |
| `patches/` | `personal/` (jalur treble), `lineage/` kurasi (jalur lineage, menciptakan target `lineage_*`) + `apply-patches.sh` idempotent (`--lineage` untuk lineage). |

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

## 2. Setup

```bash
# clone project
git clone https://github.com/sunuazizrahayu/android_treble_LineageOS_gsi.git LineageOS_gsi -b 23.2

# goto workdir (folder ini sekaligus jadi root source tree)
cd LineageOS_gsi

# init
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

# set manifest
mkdir -p .repo/local_manifests
curl -L https://raw.githubusercontent.com/sunuazizrahayu/android_treble_LineageOS_gsi/23.2/manifest.xml -o .repo/local_manifests/manifest.xml

# sync repo (lama, bisa berjam-jam)
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)

# apply patch
bash patches/apply-patches.sh .
```

Catatan:
- Kalau `apply-patches.sh` gagal dengan error git identity, set dulu:
  `git config --global user.name "nama"` dan `git config --global user.email "email"`, lalu ulangi apply-nya.
- Alternatif otomatis untuk semua langkah di atas: `./setup.sh ~/LineageOS` (lihat isi `setup.sh`).

## 3. Build

```bash
# generate definisi product (wajib, file-nya tidak ikut tersync dari git)
(cd device/phh/treble && bash generate.sh)

# load env + lunch (untuk target treble pakai lunch, bukan breakfast)
. build/envsetup.sh
lunch treble_arm64_bvN-bp4a-userdebug

# build (flag dexpreopt wajib untuk sekarang, kalau tidak gagal di tahap akhir)
make systemimage -j$(nproc --all) DISABLE_DEXPREOPT_CHECK=true
```

Hasil build:

```text
out/target/product/tdgsi_arm64_ab/system.img
```

> Varian di bawah ini butuh patches lineage kurasi yang menciptakan
> target `lineage_*` — belum dipakai di alur ini, dicatat untuk nanti:

| Varian | Filesystem | Perintah |
|---|---|---|
| VANILLA | EROFS | `bash LineageOS_gsi/build.sh --variant vanilla --fs erofs` |
| VANILLA | ext4 | `bash LineageOS_gsi/build.sh --variant vanilla --fs ext4` |
| GAPPS | EROFS | `bash LineageOS_gsi/build.sh --variant gapps --fs erofs` |
| GAPPS | ext4 | `bash LineageOS_gsi/build.sh --variant gapps --fs ext4` |

Nama lunch target lengkap (butuh patches lineage kurasi):

- VANILLA EROFS: `lineage_arm64_bvNE-bp4a-userdebug`
- VANILLA ext4: `lineage_arm64_bvN4-bp4a-userdebug`
- GAPPS EROFS: `lineage_arm64_bgNE-bp4a-userdebug`
- GAPPS ext4: `lineage_arm64_bgN4-bp4a-userdebug`

`bvN` = vanilla (tanpa GApps), `bgN` = dengan GApps (MindTheGapps). EROFS butuh kernel 5.4+ di perangkat; bila ragu/bootloop, pakai varian ext4 (read-write penuh).

## 4. Build Lineage GSI (patches lineage kurasi)

Jalur ini menghasilkan GSI Lineage yang bisa boot di HP real. Kuncinya
satu patch kurasi dari `MisterZtr/LineageOS_gsi` di `patches/lineage/`
(yang menciptakan target `lineage_*` + `lineage.mk`) — tanpa 314 file
lainnya. Patch kurasi tambahan menyusul hanya bila build terbukti butuh.
Setup-nya sama seperti bagian 2, dengan dua perbedaan:

```bash
# pakai manifest-lineage.xml (bukan manifest.xml)
curl -L https://raw.githubusercontent.com/sunuazizrahayu/android_treble_LineageOS_gsi/23.2/manifest-lineage.xml -o .repo/local_manifests/manifest.xml

# atau otomatis (sekaligus sync + apply lineage):
./setup.sh ~/LineageOS --lineage
```

Lalu terapkan **hanya** patches lineage (butuh git identity):

```bash
bash <path-ke-repo-ini>/patches/apply-patches.sh --lineage
```

Terakhir build (tanpa `generate.sh` — definisi product `lineage_*` sudah
dibawa oleh patches):

```bash
. build/envsetup.sh
breakfast lineage_arm64_bvN4-bp4a-userdebug   # vanilla ext4, contoh awal yang disarankan
make systemimage -j$(nproc --all)
```

> JANGAN campur kedua set patch. `patches/personal` + `patches/vendor_interfaces`
> (jalur treble) dan `patches/lineage` (jalur lineage) menyelesaikan masalah
> yang sama dengan cara berlawanan (charger, APN, vibrator) — dipakai
> bersamaan pasti konflik. Pilih satu jalur per source tree.

## 5. Kompres hasil (opsional)

```bash
cd out/target/product/tdgsi_arm64_ab
7z a system.img.xz system.img
```

## 6. Sync ulang / rebuild

```bash
cd ~/LineageOS_gsi
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)
bash patches/apply-patches.sh .   # ulangi setelah sync bila ada update
(cd device/phh/treble && bash generate.sh)   # wajib ulang setelah sync
make systemimage -j$(nproc --all) DISABLE_DEXPREOPT_CHECK=true
```

## Troubleshooting

- **`Don't have a product spec for ...` saat lunch** → `generate.sh` belum dijalankan, atau dijalankan dari folder yang salah (script ini menulis file ke **folder aktif**, jadi `bash device/phh/treble/generate.sh` dari root justru bikin file nyasar). Selalu pakai bentuk subshell dari root source tree: `(cd device/phh/treble && bash generate.sh)`, pastikan `treble_arm64_bvN.mk` muncul, lalu lunch ulang di terminal fresh.
- **`repo: command not found`** → pasang tool `repo` seperti di bagian dependensi, pastikan `~/.bin` ada di `PATH`.
- **Gagal apply patch / konflik** → patch harus diterapkan manual satu per satu (`git apply --check`, `git am`), biasanya karena source berubah. Untuk set kurasi, ambil ulang file patch dari `MisterZtr/LineageOS_gsi`.
- **Build OOM / killed** → kurangi jobs (`--jobs 4`), tambah RAM/swap.
- **Disk penuh** → butuh 400 GB+; bersihkan dengan `make clean` atau hapus `out/` bila ingin build ulang penuh.
- **Bootloop di HP, EROFS** → coba varian ext4; pastikan perangkat `arm64 A/B` dan vendor Android yang kompatibel.

## Kredit

- [LineageOS Team](https://github.com/LineageOS)
- [Phhusson](https://github.com/phhusson) dan [TrebleDroid](https://github.com/TrebleDroid)
- [AndyYan](https://github.com/AndyCGYan)
- [MisterZtr](https://github.com/MisterZtr/LineageOS_gsi) — referensi script, patches & manifest lineage-23.2
- [Ponces](https://github.com/ponces), [Peter Cai](https://github.com/PeterCxy), [Iceows](https://github.com/Iceows), [ChonDoit](https://github.com/ChonDoit), [Nazim N](https://github.com/naz664), [Ahnet](https://github.com/ahnet-69), [mytja](https://github.com/mytja), [cawilliamson](https://github.com/cawilliamson), [Doze-off](https://github.com/Doze-off)
