[BITS 64]
section .text
extern main
global __start
__start:
  ; At this point rdi contains important kernel information
  mov rsp, kstack_top
  mov [KInfo], rdi
  call main
  cli
  hlt

section .data
global KInfo
KInfo dq 0
section .bss
kstack_bottom:
  resb 16384
kstack_top:
