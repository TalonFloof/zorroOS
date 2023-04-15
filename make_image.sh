#!/bin/bash
nasm -f bin boot/x86_64/bios/Bootloader.S -o Bootloader.bin
rm -f zorroOS.hd
tools/fennecfstool zorroOS.hd 64 newimage 131072
tools/fennecfstool zorroOS.hd 64 bootldr Bootloader.bin
tools/fennecfstool zorroOS.hd 64 copy COPYING /OSKernel
rm Bootloader.bin