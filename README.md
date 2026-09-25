# LineageOS GSI Builder

Unofficial **LineageOS 23.2 GSI (Generic System Image)** build instructions, including the required patches and dependencies.

## Getting Started

To get started with building the unofficial LineageOS 23.2 GSI together with the required patches, you'll need to be familiar with:

* [Git and Repo](https://source.android.com/source/using-repo.html)
* [How to Build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F)

These instructions assume you are building on a Linux-based environment.

## Build Step

### Create the directories
```
mkdir LineageOS
cd LineageOS
```

### Init Repo
```
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
```

### set manifest
```
mkdir -p .repo/local_manifests && curl -fL "https://raw.githubusercontent.com/sunuazizrahayu/android_treble_LineageOS_gsi/23.2/manifest.xml" -o .repo/local_manifests/manifest.xml
```

### validate manifest
```
xmllint --noout .repo/local_manifests/manifest.xml
```

### Sync Repo
```
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)
```

### apply patch
```
bash LineageOS_gsi/patches/apply-patches.sh .
```

### BUILD

```
. build/envsetup.sh
ccache -M 50G -F 0
breakfast lineage_arm64_bvN4-bp4a-userdebug
make systemimage -j$(nproc --all)
```