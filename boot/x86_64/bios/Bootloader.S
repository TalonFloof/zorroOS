BITS 16
ORG 7c00h
__start:
    cld
    mov ax, 0 ; Set the stack to before the boot sector
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov sp, __start
    mov ax, 0x1000

    ; Load the rest of the bootloader
    xor bx, bx
    mov ah, 2
    mov al, 63
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 80h
    int 13h

times 510-($-$$) db 0 
dw 0AA55h

; From here we'll load the ZorroKernel file and enter 
