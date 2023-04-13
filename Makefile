build:
	cd kernel; make x86_64-PC; cd ..

bios: build
	./make_image.sh
.PHONY: build