build-x86_64-Legacy:
	cd kernel; make x86_64-Legacy; cd ..

bios: build-x86_64-Legacy
	./make_image.sh
.PHONY: build-x86_64-Legacy