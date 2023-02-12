.section .text

.global _start
_start:
  la sp, __rv64_init_stack_top
  call OwlKernelMain
