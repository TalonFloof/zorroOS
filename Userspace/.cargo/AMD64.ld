OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)

ENTRY(_start)

PHDRS
{
	text	PT_LOAD;
	rodata	PT_LOAD;
	data	PT_LOAD;
	bss		PT_LOAD;
}

SECTIONS {
    . = 0x1000;
    .text : ALIGN(4096) {
        *(.text .text.*)
    } : text
    .rodata : ALIGN(4096) {
        *(.rodata .rodata.*)
    } : rodata
    .data : ALIGN(4096) {
        *(.data .data.*)
    } : data
    .bss : ALIGN(4096) {
        *(COMMON)
        *(.bss .bss.*)
    } : bss
    . = ALIGN(4096);
}
