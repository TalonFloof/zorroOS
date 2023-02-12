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

    . = ALIGN(4096);
    PROVIDE(__rv64_init_stack_bottom = .);
    . += 0x2000;
    PROVIDE(__rv64_init_stack_top = .);

    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }

    . = ALIGN(4096);
}