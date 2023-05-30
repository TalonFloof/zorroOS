build: limine-zig
	nasm -f elf64 ryu/hal/x86_64/_lowlevel.s -o ryu/_lowlevel.o; \
	cd ryu; \
	zig build; \
	rm -f -r zig-cache _lowlevel.o; \
	cd ..
	cd drivers/fop; \
	zig build; \
	cd ../..

limine-zig:
	git clone https://github.com/limine-bootloader/limine-zig.git --depth=1
	rm -f -r limine-zig/.git

iso: build
	git clone --branch v4.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	mkdir -p /tmp/zorro_iso/EFI/BOOT
	mkdir /tmp/zorro_iso/Drivers/
	cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-cd-efi.bin /tmp/limine/limine-cd.bin /tmp/limine/limine.sys boot/x86_64/* ryu/Ryu /tmp/zorro_iso
	cp --force drivers/out/* /tmp/zorro_iso/Drivers
	mv /tmp/zorro_iso/BOOTX64.EFI /tmp/zorro_iso/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-cd-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label /tmp/zorro_iso -o zorroOS.iso
	zig cc /tmp/limine/limine-deploy.c -o /tmp/limine/limine-deploy
	/tmp/limine/limine-deploy zorroOS.iso
	rm -r --force /tmp/limine
	rm -r --force /tmp/zorro_iso
.PHONY: build iso