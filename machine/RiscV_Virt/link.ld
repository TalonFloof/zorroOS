OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x80200000;
    _begin = .;

    _text_begin = .;
    .text : {
        *(.text.entry)
        *(.text .text.*)
    }
    . = ALIGN(4K);
    _text_end = .;

    _rodata_begin = .;
    .rodata : {
        *(.rodata .rodata.*)
    }
    . = ALIGN(4K);
    _rodata_end = .;

    _data_begin = .;
    .data : {
        *(.data .data.*)
    }
    . = ALIGN(4K);
    _data_end = .;

    .bss : {
        *(.bss.stack)
        _bss_begin = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
    }
    . = ALIGN(4K);
    _bss_end = .;

    _end = .;
}