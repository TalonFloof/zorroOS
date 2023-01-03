CC=x86_64-elf-gcc
LD=x86_64-elf-ld
NM=x86_64-elf-nm
AS=x86_64-elf-as
ARCH=x86_64
CFILES := $(shell find ./src -type f -name '*.c')

ifeq ($(ARCH),x86_64)
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

ifeq ($(ARCH),x86_64)
	INTERNALCFLAGS := $(INTERNALCFLAGS) -D_OWL_ARCH_X86_64
endif

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-function -g

build: $(OBJFILES)

.PHONY: build x86_64-PC clean

%.o: %.c
	$(CC) -D_DEBUG_BUILD_ -D__owl__ $(INTERNALCFLAGS) $(CFLAGS) -c $< -o $@

x86_64-PC: build
	$(LD) $(OBJFILES) -r -o OwlKernel.o
	$(NM) -g --format=bsd OwlKernel.o | ./generate_symbols.py | $(AS) -c -o symbols.o
	$(LD) OwlKernel.o symbols.o -Tlink_scripts/x86_64-PC.ld -g -zmax-page-size=0x1000 -static -o OwlKernel
	rm -f symbols.o OwlKernel.o
	rm -f $(OBJFILES)

clean:
	rm -f OwlKernel OwlKernel.o symbols.o
	rm -f $(OBJFILES)