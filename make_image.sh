#!/bin/bash
dd if=/dev/zero of=zorroOS.hd bs=512 count=2097152
echo 'echo -e "o\ny\nn\n1\n\n+128M\nef00\nn\n2\n\n\n\nw\ny\n" | gdisk zorroOS.hd' | sh
dev_mount=`losetup -f | egrep -o '[0-9]+'`
losetup /dev/loop${dev_mount} zorroOS.hd -P
mkfs.vfat /dev/loop${dev_mount}p1 -F 32
# tools/fennecfstool /dev/loop${dev_mount}p2 0 newimage
echo $(stat --format="%s/1024" /dev/loop${dev_mount}p2 | bc)
losetup -d /dev/loop${dev_mount}