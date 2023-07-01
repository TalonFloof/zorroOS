bits 64
section .text
;============================================
; ISR

%macro pushaq 0
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro popaq 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

extern ExceptionHandler
extern IRQHandler

%macro ISR_ERROR_CODE 1
	global int%1
	int%1:
        cli
        pushaq
        mov rdi, %1
        mov rsi, rsp
        call ExceptionHandler
        popaq
        add rsp, 8
        iretq
%endmacro

%macro ISR_NO_ERROR_CODE 1
	global int%1
	int%1:
		cli
        o64 push 0
        pushaq
        mov rdi, %1
        mov rsi, rsp
        call ExceptionHandler
        popaq
        add rsp, 8
        iretq
%endmacro

%macro IRQ 1
	global int%1
	int%1:
        cli
        o64 push 0
        pushaq
        mov rdi, %1
        mov rsi, rsp
        call IRQHandler
        popaq
        add rsp, 8
        iretq
%endmacro


ISR_NO_ERROR_CODE  0
ISR_NO_ERROR_CODE  1
ISR_NO_ERROR_CODE  2
ISR_NO_ERROR_CODE  3
ISR_NO_ERROR_CODE  4
ISR_NO_ERROR_CODE  5
ISR_NO_ERROR_CODE  6
ISR_NO_ERROR_CODE  7
ISR_ERROR_CODE 8
ISR_NO_ERROR_CODE  9
ISR_ERROR_CODE 10
ISR_ERROR_CODE 11
ISR_ERROR_CODE 12
ISR_ERROR_CODE 13
ISR_ERROR_CODE 14
ISR_NO_ERROR_CODE  15
ISR_NO_ERROR_CODE  16
ISR_ERROR_CODE  17
ISR_NO_ERROR_CODE  18
ISR_NO_ERROR_CODE 19
ISR_NO_ERROR_CODE 20
ISR_NO_ERROR_CODE 21
ISR_NO_ERROR_CODE 22
ISR_NO_ERROR_CODE 23
ISR_NO_ERROR_CODE 24
ISR_NO_ERROR_CODE 25
ISR_NO_ERROR_CODE 26
ISR_NO_ERROR_CODE 27
ISR_NO_ERROR_CODE 28
ISR_NO_ERROR_CODE 29
ISR_ERROR_CODE 30
ISR_NO_ERROR_CODE 31

%assign num 32
%rep 256-32
    IRQ num
%assign num (num + 1)
%endrep

section .rodata
global ISRTable
ISRTable:
%assign num 0
%rep 256-32
    dq int%[num]
%assign num (num + 1)
%endrep
section .text

;============================================
; Syscall
global _RyuSyscallHandler
extern RyuSyscallDispatch
_RyuSyscallHandler:
    cli
    swapgs
    mov [gs:0], rsp
    mov rsp, [gs:8]
    
    push qword 0x3b
    push qword [gs:0]
    push r11
    push qword 0x43
    push rcx
    push qword 0
    swapgs
    cld
    pushaq
    mov rdi, rsp
    xor rbp, rbp
    call RyuSyscallDispatch
    popaq
    
    cli
    swapgs
    mov rsp, [gs:0]
    swapgs
    o64 sysret

;============================================
; Context
global ContextEnter
ContextEnter:
    mov rsp, rdi
    popaq
    add rsp, 8
    iretq
    ud2
    ud2

global ContextSetupFPU
ContextSetupFPU:
    push rax
    mov rax, cr0
    and al, 0xfb
    or al, 0x22
    mov cr0, rax
    mov rax, cr4
    or eax, 0x600
    mov cr4, rax
    fninit
    pop rax
    ret

global ThreadYield
ThreadYield:
    ; rip = 0
    push rcx ; rip = 8
    mov rcx, rsp
    add rsp, 8
    push qword 0x30 ; rip = 16
    push rcx ; rip = 24
    pushfq ; rip = 32
    push qword 0x28 ; rip = 40
    mov rcx, qword [rsp+40]
    push rcx ; rip = 48
    mov rcx, qword [rsp+40] ; Get the original RCX value
    push qword 0
    pushaq
    mov rdi, 0xfd ; Reschedule Pseudo-IPI
    mov rsi, rsp
    swapgs
    mov rsp, [gs:16]
    swapgs
    call IRQHandler
    ud2
    ud2