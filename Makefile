build:
	cd kernel; make x86_64-PC; cd ..

hd: build
	# git clone --branch v4.x-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine
	./make_image.sh
.PHONY: build