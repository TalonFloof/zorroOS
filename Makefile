build:
	cd kernel; make x86_64-PC; cd ..

iso: build
	git clone --branch v4.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	mkdir -p /tmp/zorro_iso/EFI/BOOT
	cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-cd-efi.bin /tmp/limine/limine-cd.bin /tmp/limine/limine.sys boot/x86_64/* kernel/OwlKernel /tmp/zorro_iso
	mv /tmp/zorro_iso/BOOTX64.EFI /tmp/zorro_iso/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-cd-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label /tmp/zorro_iso -o zorroOS.iso
	$(CC) /tmp/limine/limine-deploy.c -o /tmp/limine/limine-deploy
	/tmp/limine/limine-deploy zorroOS.iso
	rm -r --force /tmp/limine
	rm -r --force /tmp/zorro_iso

.PHONY: build iso