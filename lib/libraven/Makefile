CFILES := $(shell find . -type f -name '*.c')

BASECFILES := $(shell basename -a $(CFILES))
BASEOBJFILES := $(patsubst %.c,%.o,$(BASECFILES))

OBJFILES := $(patsubst %.c,%.o,$(CFILES))

.PHONY: build-x86_64

build-x86_64: $(OBJFILES)
	zig ar rcs libraven.a $(BASEOBJFILES)
	rm $(BASEOBJFILES)

%.o: %.c
	zig cc -I../libzorro --target=x86_64-freestanding-none -O3 -c $< -o $(shell basename -a $@)