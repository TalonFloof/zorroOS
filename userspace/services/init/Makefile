CFILES := $(shell find . -type f -name '*.c')

build:
	zig cc --target=x86_64-freestanding-none -ffreestanding -mabi=sysv -mno-red-zone -I../../../lib/libzorro -c $(CFILES) ../../../lib/libzorro/libzorro.o -o init.o
	zig cc --target=x86_64-freestanding-none -ffreestanding -mabi=sysv -mno-red-zone -nostdlib -T../../../lib/link-scripts/x86_64.ld init.o -o ../../../root/bin/init
	rm init.o