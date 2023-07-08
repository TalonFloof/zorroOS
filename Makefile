build: limine-zig
	nasm -f elf64 ryu/hal/x86_64/_lowlevel.s -o ryu/_lowlevel.o; \
	cd ryu; \
	zig build -Doptimize=ReleaseSafe; \
	rm -f -r zig-cache _lowlevel.o; \
	cd ..
	mkdir -p drivers/out
	cd drivers/ps2; \
	zig build -Doptimize=ReleaseSmall; \
	cd ../..
	cd drivers/pci; \
	zig build -Doptimize=ReleaseSmall; \
	cd ../..
	cd lib; \
	make; \
	cd ..
	cd userspace; \
	make; \
	cd ..
	cd files/iconData; \
	python3 genIconPack.py; \
	cd ../..

limine-zig:
	git clone https://github.com/limine-bootloader/limine-zig.git --depth=1
	rm -f -r limine-zig/.git

ramdks: build
	rm -f ramdks.cpio
	cd root; (((find . -type f | cut -c 3-) | cpio -o -v --block-size=1) > ../ramdks.cpio); cd ..

iso: build ramdks
	git clone --branch v5.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	mkdir -p /tmp/zorro_iso/EFI/BOOT
	mkdir /tmp/zorro_iso/Drivers/
	cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-uefi-cd.bin /tmp/limine/limine-bios-cd.bin /tmp/limine/limine-bios.sys boot/x86_64/* ramdks.cpio ryu/Ryu /tmp/zorro_iso
	cp --force drivers/out/* /tmp/zorro_iso/Drivers
	mv /tmp/zorro_iso/BOOTX64.EFI /tmp/zorro_iso/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -b limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label /tmp/zorro_iso -o zorroOS.iso
	zig cc /tmp/limine/limine.c -o /tmp/limine/limine
	/tmp/limine/limine bios-install zorroOS.iso
	rm -r --force /tmp/limine
	rm -r --force /tmp/zorro_iso
.PHONY: build iso