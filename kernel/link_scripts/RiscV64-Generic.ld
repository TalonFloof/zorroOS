OUTPUT_ARCH( "riscv" )
OUTPUT_FORMAT( "elf64-littleriscv" )
ENTRY( _start )

SECTIONS
{
    . = 0x80200000;

    .text : {
        *(.text .text.*)
    }

    . = ALIGN(4096);

    .rodata : {
        *(.rodata .rodata.*)
    }

   . = ALIGN(4096);

    .data : {
        *(.data .data.*)
    }

    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }

    . = ALIGN(4096);

    __memory_begin = .;
    . = 0x80000000+128M; /* Change this to the size of the memory within your board*/
    __memory_end = .;
}