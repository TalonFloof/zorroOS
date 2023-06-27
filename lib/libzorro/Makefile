CFILES := $(shell find . -type f -name '*.c')

build-x86_64:
	zig cc -I. --target=x86_64-freestanding-none -ffreestanding -mabi=sysv -mno-red-zone -D_LIBZORRO_TARGET_X86_64 -c $(CFILES) CRTs/x86_64/crt0.s -o libzorro.o