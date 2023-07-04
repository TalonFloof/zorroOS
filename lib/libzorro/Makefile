CFILES := $(shell find . -type f -name '*.c')

BASECFILES := $(shell basename -a $(CFILES))
BASEOBJFILES := $(patsubst %.c,%.o,$(BASECFILES))

OBJFILES := $(patsubst %.c,%.o,$(CFILES))

.PHONY: build-x86_64

build-x86_64: $(OBJFILES)
	zig cc -I. --target=x86_64-freestanding-none -O0 -D_LIBZORRO_TARGET_X86_64 -c CRTs/x86_64/crt0.s -o crt0.o
	zig ar rcs libzorro.a $(BASEOBJFILES)
	rm $(BASEOBJFILES)

%.o: %.c
	zig cc -I. --target=x86_64-freestanding-none -D_LIBZORRO_TARGET_X86_64 -O3 -c $< -o $(shell basename -a $@)