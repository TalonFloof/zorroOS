BITS 16
stack_end:
    jmp 0x7c0:stage1
stage1:
    cld
    mov ax, 0 ; Set the stack to before the boot sector
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov sp, stack_end
    mov ax, 0x8000

    ; Load the rest of the bootloader
    xor bx, bx
    mov ah, 2
    mov al, 63
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 80h
    int 13h

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
	jz a20err

    jmp 0x800:0

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
a20failmsg db "A20 Gate refusing to open! (that's just rude...)", 10, 13,0

times 510-($-$$) db 0 
dw 0AA55h

; From here we'll enter 32-bit mode and load the ZorroKernel. Then we'll enter 64-bit mode and jump into it
stage2:
    jmp $