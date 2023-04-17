ARCH=x86_64
CFILES := $(shell find ./src -type f -name '*.c')

ifeq ($(ARCH),x86_64)
	CC=x86_64-elf-gcc
	LD=x86_64-elf-ld
	NM=x86_64-elf-nm
	AS=x86_64-elf-as
	OBJCOPY=x86_64-elf-objcopy
	CFILES := $(CFILES) $(shell find ./architectures/x86_64/ -type f -name '*.c')
endif

OBJFILES := $(patsubst %.c,%.o,$(CFILES))

INTERNALCFLAGS :=               \
	-ffreestanding                \
	-std=gnu90                    \
	-fno-omit-frame-pointer       \
	-fno-stack-protector          \
	-fno-stack-check              \
	-fno-pic                      \
	-fno-pie                      \
	-ffunction-sections           \
	-fdata-sections               \
	-fno-strict-aliasing          \
	-Isrc/Include

ifeq ($(ARCH),x86_64)
	INTERNALCFLAGS := $(INTERNALCFLAGS) \
	-mabi=sysv                    \
	-mno-80387                    \
	-mno-mmx                      \
	-mno-3dnow                    \
	-mno-sse                      \
	-mno-sse2                     \
	-mno-red-zone                 \
	-Wno-address-of-packed-member \
	-mcmodel=kernel               \
	-D_X86_64
endif

CFLAGS ?= -O3 -Wall -Wextra -Wno-unused-function -g

build: $(OBJFILES)

.PHONY: build x86_64-Limine clean

%.o: %.c
	$(CC) -D_DEBUG_BUILD_ -D__zorrokrnl__ $(INTERNALCFLAGS) $(CFLAGS) -c $< -o $@

x86_64-Limine: build
	$(CC) $(OBJFILES) -O3 -r -o Kernel.o
	nasm -f elf64 architectures/x86_64/ISR.S -o architectures/x86_64/ISR.o
	$(OBJCOPY) -I binary -O elf64-x86-64 ../files/knxt.psf knxt.o
	$(OBJCOPY) -I binary -O elf64-x86-64 ../files/unifont.psf unifont.o
	$(OBJCOPY) -I binary -O elf64-x86-64 ../files/terminus.psf terminus.o
	$(LD) knxt.o unifont.o terminus.o architectures/x86_64/ISR.o Kernel.o -Tlink_scripts/x86_64-Limine.ld -g -zmax-page-size=0x1000 -static -o ZorroKernel
	rm -f Kernel.o knxt.o unifont.o terminus.o architectures/x86_64/ISR.o
	rm -f $(OBJFILES)

clean:
	rm -f Kernel.o knxt.o unifont.o terminus.o architectures/x86_64/ISR.o
	rm -f $(OBJFILES)