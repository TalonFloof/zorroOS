section .text

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

global _ZorroSyscallHandler
extern _ZorroSyscallDispatch
_ZorroSyscallHandler:
    swapgs
    mov [gs:8], rsp
    mov rsp, [gs:0]
    
    push qword 0x1b
    push qword [gs:0x8]
    push r11
    push qword 0x18
    push rcx
    swapgs
    sti
    cld
    pushaq
    mov rdi, rsp
    xor rbp, rbp
    call _ZorroSyscallDispatch
    popaq
    
    cli
    swapgs
    mov rsp, [gs:8]
    swapgs
    o64 sysret