[BITS 16]
jmp 0x7c0:stage1
stage1:
    cld
    jmp $
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov sp, 0x7c00
.loop:
    cli
    hlt
    jmp .loop

    ; Load the rest of the bootloader
    mov bx, 0x8000
    mov ah, 2
    mov al, 63
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 80h
    ;int 13h

    mov si, splashmsg
    call print

    call checkIBF
	mov al, 0xd0
	out 0x64, al
	call checkOBE
	in al, 0x60
	push ax
	call checkIBF
	mov al, 0xd1
	out 0x64, al
	call checkIBF
	pop ax
	or ax, 2
	out 0x60, al
	call checkIBF
	mov al, 0xd0
	out 0x64, al
	call checkOBE
	in al, 0x60
	test al, 2
	jnz a20err

    jmp stage2

checkOBE:
	in al, 0x64
	test al, 1
	jz checkOBE
	ret
checkIBF:
	in al, 0x64
	test al, 2
	jnz checkIBF
	ret
a20err:
    mov si, a20failmsg
	call print
	jmp $

print:
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
	ret

; The rest of this sector will be used for storing extra data
splashmsg db "zorroOS BIOS Bootloader", 10, 13, "Copyright (C) 2023 TalonFox", 10, 13, 0
a20failmsg db "A20 Gate refusing to open! (that's just rude...)", 10, 13,0

times 510-($-$$) db 0 
dw 0AA55h

; From here we'll enter 32-bit mode and load the ZorroKernel. Then we'll enter 64-bit mode and jump into it
stage2:
    jmp $

times 32768-($-$$) db 0 