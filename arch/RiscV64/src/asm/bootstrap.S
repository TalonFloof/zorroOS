.option norvc
.section .data

.section .text.init

.global _start
_start:
    csrr t0, mhartid # Branch off if not Hart #0
    bnez t0, 3f
    csrw satp, zero # Just in case SATP isn't zeroed out already
.option push
.option norelax
	la gp, _global_pointer
.option pop
    # Zero BSS
    la a0, _bss_start
	la a1, _bss_end
	bgeu a0, a1, 2f
1:
	sd zero, (a0)
	addi a0, a0, 8
	bltu a0, a1, 1b
2: # Final Setup & Jump into Main function
    la sp, _stack
    li t0, (0b11 << 11) | (1 << 7) | (1 << 3)
    csrw mstatus, t0
    la t1, main
    csrw mepc, t1
    la t2, trap_vector
    csrw mtvec, t2
    li t3, (1 << 3) | (1 << 7) | (1 << 11)
    csrw mie, t3
    la ra, 4f
    mret
4:
	wfi
	j 4b
3: # Loop infinitely if not Hart #0 ( For now, ;) )
	wfi
	j 3b