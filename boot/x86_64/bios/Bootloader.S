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
    
    mov [bootdsk], dl

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
    mov dl, [bootdsk]
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
bootdsk db 0

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
    mov cr0, eax
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
    mov eax, [video_mode]
    test eax, eax
    jz .noconfig
    jmp .afterconfig
.noconfig:
    mov si, novmode
    call print
.rep:
	push es
	mov ax, 0x4F00
    mov di, buffer
    int 0x10
	pop es
    mov si, [buffer+14]
    mov ax, [buffer+16]
    mov fs, ax
.loop:
    mov ax, [fs:si]
	cmp ax, 0xffff
    jz .rep
	pushad
    mov cx, ax
    mov ax, 0x4f01
    mov di, buffer
    int 10h
	popad
	mov dl, [es:di+25]
	cmp dl, 32
	jb .next
	push ax
    push esi
	mov si, mode1
    call print
    call int_to_string
    mov si, ax
    call print
	pop esi
	pop ax
	push esi
    mov si, mode2
    call print
    mov ax, [es:di+18]
    call int_to_string
	mov si, ax
    call print
    mov si, mode3
    call print
    mov ax, [es:di+20]
    call int_to_string
    mov si, ax
    call print
    mov si, mode3
    call print
    xor ax, ax
    mov al, [es:di+25]
    call int_to_string
    mov si, ax
    call print
    mov si, mode4
    call print
	push es
	mov ax, 0x4F00
    mov di, buffer
    int 0x10
	pop es
    pop esi
    mov ah, 0
    int 0x16
	push esi
	mov si, nl
	call print
	pop esi
	mov bx, [fs:si]
	cmp al, 'y'
	jz .afterloop
    add si, 2
    jmp .loop
.next:
	add si, 2
	push es
	mov ax, 0x4F00
    mov di, buffer
    int 0x10
	pop es
	jmp .loop
.afterloop:
	mov [video_mode], bx
.afterconfig:
    mov ax, 0x4f01
    mov cx, [video_mode]
    mov di, buffer
    int 0x10
    mov eax, [buffer + 0x28]
    mov [video_addr], eax
    mov ax, [buffer + 18]
    mov [video_width], ax
    mov ax, [buffer + 20]
    mov [video_height], ax
    mov al, [buffer + 25]
    mov [video_bpp], al
get_memmap:
    mov di, buffer
    mov esi, 0x22000
    xor ebx, ebx
    mov edx, 0x0534D4150
    mov eax, 0xe820
    mov [es:di + 20], dword 1
    mov ecx, 24
    int 0x15
    jc short .failed
    mov edx, 0x0534D4150
    cmp eax, edx
	jne short .failed
	test ebx, ebx
	je short .failed
    jmp .loop
.e820lp:
    test ebx, ebx
    je .loopend
	mov eax, 0xe820
	mov [es:di + 20], dword 1
	mov ecx, 24
	int 0x15
	jc short .loopend
	mov edx, 0x0534D4150
.loop:
    cmp byte [es:di + 16], 1
    jne .e820lp
    mov ecx, [es:di + 8]
	or ecx, [es:di + 12]
	jz .e820lp
    mov ecx, [es:di]
    mov [esi], ecx
    mov ecx, [es:di+4]
    mov [esi+4], ecx
    mov ecx, [es:di+8]
    mov [esi+8], ecx
    mov ecx, [es:di+12]
    mov [esi+12], ecx
    add esi, 16
    jmp .e820lp
.failed:
    mov si, e820fail
    call print
.halt:
    cli
    hlt
    jmp short .halt
.loopend:
    mov dword [esi], 0
    mov dword [esi+4], 0
    mov dword [esi+8], 0
    mov dword [esi+12], 0
    mov dword [memmap], 0x22000
kernelload:
    mov si, kloadmsg
	call print
	mov eax, 64
    mov cx, 1
    call read_sector
    mov ebx, 0x10000
    mov eax, [ebx+0x30]
    cmp eax, 0x6E654680
    jne .badmagic
    mov eax, [ebx+0x34]
    cmp eax, 0x8063656E
    je .startload
.badmagic:
    mov si, badmagicmsg
    call print
.L1:
    cli
    hlt
    jmp short .L1
.startload:
    mov eax, [ebx]
    mov [inodes], eax
    mov eax, [ebx+0x4]
    add eax, 64
    mov [inodestart], eax
    mov eax, [ebx+0xc]
    mov [zones], eax
    mov eax, [ebx+0x10]
    add eax, 64
    mov [zonestart], eax
    mov eax, [ebx+0x18]
    mov [zonesize], eax
    mov eax, [ebx+0x20]
    add eax, 64
    mov [zttstart], eax

    mov eax, [ebx+0x8]
    mov edx, [zonesize]
    shr edx, 9
    mul edx
    mov [zttsize], eax

    mov eax, [inodestart]
    mov cx, 1
    call read_sector
    mov esi, 0x10100
    mov eax, [esi+0x10]
    push esi
    push eax
    mov si, kload2msg
    call print
    call long_to_hex
    mov si, ax
    call print
    mov si, kload3msg
    call print
    pop eax
    pop esi
    ; Start copying data to the 1 MiB mark
    mov eax, [esi+0x30]
    inc eax
    mov edi, 0x100000
.readloop:
    dec eax
    cmp eax, 0xfffffffe
    jae bootos
    call read_zone
    mov ecx, [zonesize]
    mov esi, 0x10000
.copy:
    mov edx, [esi]
    mov [edi], edx
    add esi, 4
    add edi, 4
    sub ecx, 4
    cmp ecx, 0
    ja .copy
    jmp .readloop
bootos:
    mov ax, 0x4f02
    mov bx, [video_mode]
    or bx, 0x4000 ; LFB
    int 0x10
    ; WE ARE NOW GOING TO ENTER LONG MODE, THERE'S NO GOING BACK...
    cli
    mov eax, 0x20000
    mov dword [eax], 0x21003
    mov dword [eax+4], 0
    mov eax, 0x21000
    mov cx, 512
    xor ebx, ebx
.pageloop:
    mov edx, ebx
    shl edx, 30
    or edx, 0x83
    mov dword [eax], edx
    mov edx, ebx
    shr edx, 2
    mov dword [eax+4], edx
    add eax, 8
    inc ebx
    dec cx
    cmp cx, 0
    ja .pageloop

    lidt [idtp]
    mov eax, 10100000b ; Set PAE and PGE
    mov cr4, eax

    mov edx, 0x20000
    mov cr3, edx

    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x00000100
    wrmsr

    mov ebx, cr0
    or ebx,0x80000001
    mov cr0, ebx
    lgdt [gdtp]
    jmp 0x18:longmode
[BITS 64]
longmode:
    mov ax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rdi, config_magic
    jmp 0x100000
[BITS 16]

; read_sector(eax: SectorLow, cx: SectorCount)
read_sector:
    pushad
    push es
    ; Write the descriptor block for the extended read
    mov byte [buffer], 10h
    mov byte [buffer+1], 0
    mov word [buffer+2], cx
    mov word [buffer+4], 0
    mov word [buffer+6], 1000h
    mov dword [buffer+8], eax
    mov dword [buffer+12], 0
    ; Run the BIOS command
    mov ah, 42h
    mov dl, [bootdsk]
    mov esi, buffer
    clc
    int 13h
    jc .readerr
    pop es
    popad
    ret
.readerr:
    mov si, readfail
    call print
    mov eax, dword [buffer+8]
    call long_to_hex
    mov si, ax
    call print
.halt:
    cli
    hlt
    jmp .halt

; Reads a FennecFS Zone, Returns the next Zone in the chain
; read_zone(eax: Zone): (eax: Next Zone)
read_zone:
    push ebx
    push ecx
    push edx
    push eax
    shr eax, 7
    mov ebx, [zttstart]
    add eax, ebx
    mov cx, 1
    call read_sector
    pop eax
    mov ebx, eax
    and ebx, 0x7f
    shl ebx, 2
    add ebx, 0x10000
    mov ebx, [ebx]
    pop edx
    pop ecx
    push ecx
    push edx
    mov ecx, [zonesize]
    shr ecx, 9
    xor edx, edx
    mul ecx
    add eax, [zonestart]
    call read_sector
    mov eax, ebx
    pop edx
    pop ecx
    pop ebx
    ret

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

long_to_hex:
    pushad
    mov cl, 8
    mov si, .t
    mov byte [si], '0'
    mov byte [si+1], 'x'
    add si, 2
.loop:
    mov ebx, eax
    shr ebx, 28
    cmp bl, 9
    ja .letter
    add bl, '0'
    jmp .next
.letter:
    add bl, 'W' ; W+10 = a (big brain time)
.next:
    mov byte [si], bl
    inc si
    shl eax, 4
    dec cl
    cmp cl, 0
    ja .loop
    mov byte [si], 0
    popad
    mov eax, .t
    ret

    .t times 11 db 0

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

idtp:
    dw 0
    dd 0

mode1 db "mode ", 0
mode2 db " (", 0
mode3 db "x", 0
mode4 db ") (Y/N)? ", 0
nl db 13, 0
novmode db "Please select a video mode (this can be reconfigured later)", 13, 10, 0
kloadmsg db 13, 10, "Loading Kernel ", 0
kload2msg db "(size=", 0
kload3msg db ")", 13, 10, 0
badmagicmsg db 13, 10, "Invalid FennecFS Superblock!", 13, 10, 0
readfail db "READ FAIL ", 0
e820fail db "E820 Failure", 13, 10, 0
filename db "OSKernel", 0
nokrnlmsg db 13, 10, "Please ensure that the file ", '"', "OSKernel", '"', " exists in the root directory.", 13, 10, 0

buffer times 512 db 0

inodes dd 0
zones dd 0
zonesize dd 0
zttsize dd 0
zonestart dd 0
inodestart dd 0
zttstart dd 0

times (32768-512)-($-$$) nop
config_magic db "zorroCfg"
video_mode dd 0 ; This is used to get the configuration for video, however, its not set
video_addr dq 0
video_width dw 0
video_height dw 0
video_bpp db 0
memmap dq 0
times 32768-($-$$) db 0