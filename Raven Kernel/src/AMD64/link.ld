/* Tell the linker that we want an x86_64 ELF64 output file */
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
 
/* We want the symbol _start to be our entry point */
ENTRY(_start)
 
/* Define the program headers we want so the bootloader gives us the right */
/* MMU permissions */
PHDRS
{
    null    PT_NULL    FLAGS(0) ;                   /* Null segment */
    text    PT_LOAD    FLAGS((1 << 0) | (1 << 2)) ; /* Execute + Read */
    rodata  PT_LOAD    FLAGS((1 << 2)) ;            /* Read only */
    data    PT_LOAD    FLAGS((1 << 1) | (1 << 2)) ; /* Write + Read */
    header  PT_LOAD    FLAGS((1 << 0) | (1 << 1) | (1 << 2));
}
 
SECTIONS
{
    /* We wanna be placed in the topmost 2GiB of the address space, for optimisations */
    /* and because that is what the stivale2 spec mandates. */
    /* Any address in this region will do, but often 0xffffffff80000000 is chosen as */
    /* that is the beginning of the region. */
    . = 0xffffffff80000000;

    .stivale2hdr : {
        QUAD(0) /* Entry point */
        QUAD(__stack_high) /* Stack */
        QUAD(0x1e) /* Flags */
        QUAD(__framebuffer_tag) /* Tags */
    } :header

    .text : {
        *(.text .text.*)
    } :text
 
    . += CONSTANT(MAXPAGESIZE);
 
    .rodata : {
        __framebuffer_tag = .;
        QUAD(0x3ecc1bc43d0f7971) /* identifier */
        QUAD(__after_framebuffer_tag) /* next */
        SHORT(0) /* width */
        SHORT(0) /* height */
        SHORT(0) /* bpp */
        __after_framebuffer_tag = .;

        __smp_tag = .;
        QUAD(0x1ab015085f3273df) /* identifier */
        QUAD(__after_smp_tag) /* next */
        QUAD(0) /* flags */
        __after_smp_tag = .;
        QUAD(0xAAAAAAAAAAAAAAAA)
        QUAD(0)

        *(.rodata .rodata.*)
    } :rodata
 
    /* Move to the next memory page for .data */
    . += CONSTANT(MAXPAGESIZE);
 
    .data : {
        *(.data .data.*)
    } :data
 
    .bss : {
        __stack_low = .;
        . += 64K;
        __stack_high = .;
        *(COMMON)
        *(.bss .bss.*)
    } :data
}
