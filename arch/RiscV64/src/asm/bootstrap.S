.section .text.entry

.global _start
_start:
    sfence.vma zero, zero # Invalidate Page Table
    la sp, _initial_stack_end
    call main

.section .bss.stack
.global _initial_stack_begin
_initial_stack_begin:
.space 4096 * 16
.global _initial_stack_end
_inital_stack_end: