build:
	cd kernel; make x86_64-PC; cd ..

hd: build
	# git clone --branch v4.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	qemu-img create -f qcow2 zorroOS.qcow2 4G
	sudo qemu-nbd -c /dev/nbd0 zorroOS.qcow2
	echo 'echo -e "o\ny\nn\n1\n\n+256M\nef00\nn\n2\n\n\n\nw\ny\n" | gdisk /dev/nbd0' | sh
	mkfs.vfat /dev/nbd0p1 -F 32
	tools/fennecfstool /dev/nbd0p2 0 newimage
	echo $(stat --format="%s/1024" /dev/nbd0p2 | bc)
	sudo qemu-nbd -d /dev/nbd0

.PHONY: build