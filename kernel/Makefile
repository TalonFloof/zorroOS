VFILES := $(shell find ./ -type f -name '*.v')

INTERNALCFLAGS :=                 \
	-ffreestanding                \
	-std=gnu99                    \
	-nostdinc                     \
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
	-Wno-unused-value             \
	-Wno-unused-label             \
	-Wno-unused-function          \
	-Wno-unused-variable          \
	-Wno-unused-parameter         \
	-Ifreestanding_headers        \
	-Icheaders

CFLAGS ?= -O0 -Wall -Wextra -g -pipe

build: freestanding_headers
	v -os linux -freestanding -bare-builtin-dir modules/zorro_builtin -enable-globals -nofloat -autofree -gc none -d no_backtrace -o kernel.c .
	clang -D__zorro__ -O0 -g -pipe $(INTERNALCFLAGS) -w -c kernel.c -o kernel.o
	# rm kernel.c

x86_64-PC: build
	$(LD) kernel.o -Tlink_scripts/x86_64-PC.ld -nostdlib -zmax-page-size=0x1000 -static -gc-sections -o ZorroKernel
	rm *.o

freestanding_headers:
	git clone https://github.com/mintsuki/freestanding_headers.git

clean:
	rm -r freestanding_headers
	rm ZorroKernel
	rm kernel.c