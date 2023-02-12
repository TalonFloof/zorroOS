ARCH=RiscV64
CFILES := $(shell find ./src -type f -name '*.c')

ifeq ($(ARCH),x86_64)
	CC=x86_64-unknown-elf-gcc
	LD=x86_64-unknown-elf-ld
	NM=x86_64-unknown-elf-nm
	AS=x86_64-unknown-elf-as
	CFILES := $(CFILES) $(shell find ./architectures/x86_64/ -type f -name '*.c')
endif
ifeq ($(ARCH),RiscV64)
	CC=/opt/riscv-c/bin/riscv64-unknown-elf-gcc
	LD=/opt/riscv-c/bin/riscv64-unknown-elf-ld
	NM=/opt/riscv-c/bin/riscv64-unknown-elf-nm
	AS=/opt/riscv-c/bin/riscv64-unknown-elf-as
	CFILES := $(CFILES) $(shell find ./architectures/riscv64/ -type f -name '*.c')
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
	-Isrc

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
	-D_OWL_ARCH_X86_64
endif

ifeq ($(ARCH),RiscV64)
	INTERNALCFLAGS := $(INTERNALCFLAGS) \
	-march=rv64gc                 \
	-mabi=lp64                    \
	-mcmodel=medany               \
	-D_OWL_ARCH_RISCV64
endif

CFLAGS ?= -O3 -Wall -Wextra -Wno-unused-function -g

build: $(OBJFILES)

.PHONY: build x86_64-PC RiscV64-Generic clean

%.o: %.c
	$(CC) -D_DEBUG_BUILD_ -D__owl__ $(INTERNALCFLAGS) $(CFLAGS) -c $< -o $@

x86_64-PC: build
	$(CC) $(OBJFILES) -O3 -r -o OwlKernel.o
	$(NM) -g --format=bsd OwlKernel.o | ./generate_symbols.py | $(AS) -c -o symbols.o
	$(LD) OwlKernel.o symbols.o -Tlink_scripts/x86_64-PC.ld -g -zmax-page-size=0x1000 -static -o OwlKernel
	rm -f symbols.o OwlKernel.o
	rm -f $(OBJFILES)

RiscV64-Generic: build
	$(CC) -D_DEBUG_BUILD_ -D__owl__ $(INTERNALCFLAGS) $(CFLAGS) -c architectures/riscv64/start.s -o architectures/riscv64/start.o
	$(CC) $(OBJFILES) architectures/riscv64/start.o -O3 -r -o OwlKernel.o
	# $(NM) -g --format=bsd OwlKernel.o | ./generate_symbols.py | $(AS) -mabi=lp64 -c -o symbols.o
	$(LD) OwlKernel.o -Tlink_scripts/RiscV64-Generic.ld -g -zmax-page-size=0x1000 -static -o OwlKernel
	rm -f OwlKernel.o
	rm -f architectures/riscv64/start.o
	rm -f $(OBJFILES)

clean:
	rm -f OwlKernel OwlKernel.o symbols.o
	rm -f $(OBJFILES)