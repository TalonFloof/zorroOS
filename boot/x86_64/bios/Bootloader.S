[BITS 16]
[ORG 0x7c00]
jmp 0:stage1
stage1:
    cld
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov sp, 0x7c00

    mov ax, 3
    int 10h

    mov cx, 0x0007
    mov ah, 1
    int 10h

    xor ax, ax
    mov dx, 0x03c8
    out dx, al
    inc dx
    mov al, 7
    out dx, al
    out dx, al
    mov al, 11
    out dx, al
    mov al, 7
    dec dx
    out dx, al
    inc dx
    mov al, 0x2e
    out dx, al
    mov al, 0x30
    out dx, al
    mov al, 0x37
    out dx, al

    ; Load the rest of the bootloader
    mov bx, 0x7e00
    mov ah, 2
    mov al, 63
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 80h
    int 13h

    mov si, splashmsg
    call print

    cli ; Enable the A20 Gate
    call a20wait
    mov al,0xAD
    out 0x64,al
    call a20wait
    mov al,0xD0
    out 0x64,al
    call a20wait2
    in al,0x60
    push ax
    call a20wait
    mov al,0xD1
    out 0x64,al
    call a20wait
    pop ax
    or al,2
    out 0x60,al
    call a20wait
    mov al,0xAE
    out 0x64,al
    call a20wait
    sti

    jmp stage2

a20wait:
    in al,0x64
    test al,2
    jnz a20wait
    ret
 
a20wait2:
    in al,0x64
    test al,1
    jz a20wait2
    ret

print:
    pusha
    mov bp,sp
.cont:
    lodsb
    or al,al
    jz .dne
    mov ah,0x0e
    mov bx,0
    int 10h
    jmp .cont
.dne:
    mov sp,bp
    popa
    ret

; The rest of this sector will be used for storing extra data
splashmsg db "zorroOS Legacy BIOS Bootloader", 10, 13, "Copyright (C) 2023 TalonFox", 10, 13, 0

times 440-($-$$) nop
times 510-($-$$) db 0 
dw 0AA55h

; From here we'll enter unreal mode and load the ZorroKernel. Then we'll enter 64-bit mode and jump into it
stage2:
    ; Enter Unreal Mode
    cli
    push ds
    lgdt [gdtp]
    mov eax, cr0
    or al,1
    mov  cr0, eax
    jmp 0x8:.pmode
.pmode:
    mov bx, 0x10
    mov ds, bx
    and al,0xFE
    mov cr0, eax
    jmp 0x0:.unreal
.unreal:
    pop ds
    sti ; We're now in unreal mode, because of this, we can access memory above the 1 MiB mark
    mov eax, dword [video_mode]
    test eax, eax
    jz .noconfig
    jmp .afterloop
.noconfig:
    mov si, novmode
    call print
    mov ax, 0x4F00
    mov di, buffer
    int 0x10
    mov si, word [buffer+14]
    mov ax, word [buffer+16]
    mov fs, ax
.loop:
    mov ax, word [fs:si]
    cmp ax, 0xffff
    jz .afterloop
    push esi
    mov cx, ax
    mov ax, 0x4f01
    mov di, buffer
    int 10h
    mov si, mode1
    call print
    pop esi
    push esi
    mov ax, word [fs:si]
    call int_to_string
    mov si, ax
    call print
    mov si, mode2
    call print
    mov ax, word [es:di+18]
    call int_to_string
    mov si, ax
    call print
    mov si, mode3
    call print
    mov ax, word [es:di+20]
    call int_to_string
    mov si, ax
    call print
    mov si, mode3
    call print
    xor ax, ax
    mov al, byte [es:di+25]
    call int_to_string
    mov si, ax
    call print
    mov si, mode4
    call print
    pop esi
    mov ah, 0
    int 0x16
    add si, 2
    jmp .loop
.afterloop:
    jmp $


int_to_string:
    pusha
    mov cx, 0
    mov bx, 10
    mov di, .t
.push:
    mov dx, 0
    div bx
    inc cx
    push dx
    test ax, ax
    jnz .push
.pop:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    dec cx
    jnz .pop
    mov byte [di], 0
    popa
    mov ax, .t
    ret


    .t times 7 db 0

gdtp:
    dw gdt_end - gdt - 1
    dd gdt
gdt:
    dq 0 ; first entry 0
    db 0xff, 0xff, 0, 0, 0, 10011010b, 00000000b, 0
    db 0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
    ; 64-bit code entry
    dq 0x00209A0000000000
    ; 64-bit data entry
    dq 0x0000920000000000
gdt_end:

mode1 db "mode ", 0
mode2 db " (", 0
mode3 db "x", 0
mode4 db ") (Y/N)? ", 0
novmode db "Please select a video mode (this can be reconfigured later)", 13, 10, 0

buffer times 512 db 0

times (32768-512)-($-$$) nop
config_magic db "zorroCfg"
video_mode dd 0 ; This is used to get the configuration for video, however, its not set
times 32768-($-$$) db 0