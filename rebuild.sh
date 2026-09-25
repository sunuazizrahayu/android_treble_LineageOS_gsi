#!/bin/bash

repo sync LineageOS_gsi
bash LineageOS_gsi/patches/apply-patches.sh .
make systemimage -j$(nproc --all)
