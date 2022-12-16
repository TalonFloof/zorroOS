CC=x86_64-elf-gcc
LD=x86_64-elf-ld
ARCH=x86_64
CFILES := $(shell find ./src -type f -name '*.c')

ifeq ($(ARCH),x86_64)
	CFILES := $(CFILES) $(shell find ./architectures/x86_64/ -type f -name '*.c')
endif

OBJFILES := $(patsubst %.c,%.o,$(CFILES))



INTERNALCFLAGS :=                 \
	-ffreestanding                \
	-ansi                         \
	-fno-omit-frame-pointer       \
	-fno-stack-protector          \
	-fno-stack-check              \
	-fno-pic                      \
	-fno-pie                      \
	-ffunction-sections           \
	-fdata-sections               \
	-fno-strict-aliasing          \
	-mabi=sysv                    \
	-mno-80387                    \
	-mno-mmx                      \
	-mno-3dnow                    \
	-mno-sse                      \
	-mno-sse2                     \
	-mno-red-zone                 \
	-mcmodel=kernel               \
	-Wno-address-of-packed-member \
	-Isrc


CFLAGS ?= -O0 -Wall -Wextra -g

build: $(OBJFILES)

.PHONY: build x86_64-PC clean

%.o: %.c
	$(CC) -D_OWL_ARCH_X86_64 -D__owl__ $(INTERNALCFLAGS) $(CFLAGS) -c $< -o $@

x86_64-PC: build
	$(LD) $(OBJFILES) -Tlink_scripts/x86_64-PC.ld -nostdlib -zmax-page-size=0x1000 -static -gc-sections -o OwlKernel
	rm $(OBJFILES)

clean:
	rm -f OwlKernel
	rm -f $(OBJFILES)