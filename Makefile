build: limine-zig
	cd kernel; \
	nasm -f elf64 arch/x86_64/isr.s -o arch/x86_64/isr.o; \
	nasm -f elf64 arch/x86_64/syscall.s -o arch/x86_64/syscall.o; \
	zig build; \
	rm -f -r zig-cache; \
	cd ..
	rm -f -r kernel/arch/x86_64/isr.o kernel/arch/x86_64/syscall.o

limine-zig:
	git clone https://github.com/limine-bootloader/limine-zig.git --depth=1
	rm -f -r limine-zig/.git

iso: build
	git clone --branch v4.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	mkdir -p /tmp/zorro_iso/EFI/BOOT
	cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-cd-efi.bin /tmp/limine/limine-cd.bin /tmp/limine/limine.sys boot/x86_64/* kernel/ZorroKernel /tmp/zorro_iso
	mv /tmp/zorro_iso/BOOTX64.EFI /tmp/zorro_iso/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-cd-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label /tmp/zorro_iso -o zorroOS.iso
	zig cc /tmp/limine/limine-deploy.c -o /tmp/limine/limine-deploy
	/tmp/limine/limine-deploy zorroOS.iso
	rm -r --force /tmp/limine
	rm -r --force /tmp/zorro_iso
.PHONY: build iso