CFILES := $(shell find . -type f -name '*.c')

build:
	zig cc --target=x86_64-freestanding-none -O3 -I../../../lib/libzorro -c $(CFILES) ../../../lib/libzorro/libzorro.a ../../../lib/libzorro/crt0.o -o init.o
	zig cc --target=x86_64-freestanding-none -O3 -nostdlib -T../../../lib/link-scripts/x86_64.ld init.o -o ../../../root/bin/init
	chmod 777 ../../../root/bin/init
	rm init.o