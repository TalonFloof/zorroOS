/*
 * Wow, I can't believe I wrote this back in 2021
 * It's amazing how much more I know now than before.
 */

.section .text
.macro pushaq
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    pushq %rbp
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
.endm 

.macro popaq
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rbp
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax
.endm

.extern ExceptionHandler
.extern IRQHandler

.macro ISR_ERROR_CODE num
	.global int\num
	int\num:
        cli
        pushq 5*8(%rsp) // SS
        pushq 5*8(%rsp) // RSP
        pushq 5*8(%rsp) // RFLAGS
        pushq 5*8(%rsp) // CS
        pushq 5*8(%rsp) // RIP
        pushaq
        movq $\num, %rdi
        movq %rsp, %rsi
        movq 20*8(%rsp), %rdx
        xorq %rbp, %rbp
        call ExceptionHandler
        popaq
        iretq
.endm

.macro ISR_NO_ERROR_CODE num
	.global int\num
	int\num:
		cli
        pushaq
        movq $\num, %rdi
        movq %rsp, %rsi
        xorq %rdx, %rdx
        xorq %rbp, %rbp
        call ExceptionHandler
        popaq
        iretq
.endm

.macro IRQ num
	.global int\num
	int\num:
		cli
        pushaq
        movq $\num, %rdi
        movq %rsp, %rsi
        xorq %rbp, %rbp
        callq IRQHandler
        popaq
        iretq
.endm

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

IRQ 32
IRQ 33
IRQ 34
IRQ 35
IRQ 36
IRQ 37
IRQ 38
IRQ 39

IRQ 40
IRQ 41
IRQ 42
IRQ 43
IRQ 44
IRQ 45
IRQ 46
IRQ 47
IRQ 48
IRQ 49

IRQ 50
IRQ 51
IRQ 52
IRQ 53
IRQ 54
IRQ 55
IRQ 56
IRQ 57
IRQ 58
IRQ 59

IRQ 60
IRQ 61
IRQ 62
IRQ 63
IRQ 64
IRQ 65
IRQ 66
IRQ 67
IRQ 68
IRQ 69

IRQ 70
IRQ 71
IRQ 72
IRQ 73
IRQ 74
IRQ 75
IRQ 76
IRQ 77
IRQ 78
IRQ 79

IRQ 80
IRQ 81
IRQ 82
IRQ 83
IRQ 84
IRQ 85
IRQ 86
IRQ 87
IRQ 88
IRQ 89

IRQ 90
IRQ 91
IRQ 92
IRQ 93
IRQ 94
IRQ 95
IRQ 96
IRQ 97
IRQ 98
IRQ 99

IRQ 100
IRQ 101
IRQ 102
IRQ 103
IRQ 104
IRQ 105
IRQ 106
IRQ 107
IRQ 108
IRQ 109

IRQ 110
IRQ 111
IRQ 112
IRQ 113
IRQ 114
IRQ 115
IRQ 116
IRQ 117
IRQ 118
IRQ 119

IRQ 120
IRQ 121
IRQ 122
IRQ 123
IRQ 124
IRQ 125
IRQ 126
IRQ 127

.section .rodata
.global ISRTable
ISRTable:
    .quad int0
    .quad int1
    .quad int2
    .quad int3
    .quad int4
    .quad int5
    .quad int6
    .quad int7
    .quad int8
    .quad int9
    .quad int10
    .quad int11
    .quad int12
    .quad int13
    .quad int14
    .quad int15
    .quad int16
    .quad int17
    .quad int18
    .quad int19
    .quad int20
    .quad int21
    .quad int22
    .quad int23
    .quad int24
    .quad int25
    .quad int26
    .quad int27
    .quad int28
    .quad int29
    .quad int30
    .quad int31
    .quad int32
    .quad int33
    .quad int34
    .quad int35
    .quad int36
    .quad int37
    .quad int38
    .quad int39
    .quad int40
    .quad int41
    .quad int42
    .quad int43
    .quad int44
    .quad int45
    .quad int46
    .quad int47
    .quad int48
    .quad int49
    .quad int50
    .quad int51
    .quad int52
    .quad int53
    .quad int54
    .quad int55
    .quad int56
    .quad int57
    .quad int58
    .quad int59
    .quad int60
    .quad int61
    .quad int62
    .quad int63
    .quad int64
    .quad int65
    .quad int66
    .quad int67
    .quad int68
    .quad int69
    .quad int70
    .quad int71
    .quad int72
    .quad int73
    .quad int74
    .quad int75
    .quad int76
    .quad int77
    .quad int78
    .quad int79
    .quad int80
    .quad int81
    .quad int82
    .quad int83
    .quad int84
    .quad int85
    .quad int86
    .quad int87
    .quad int88
    .quad int89
    .quad int90
    .quad int91
    .quad int92
    .quad int93
    .quad int94
    .quad int95
    .quad int96
    .quad int97
    .quad int98
    .quad int99
    .quad int100
    .quad int101
    .quad int102
    .quad int103
    .quad int104
    .quad int105
    .quad int106
    .quad int107
    .quad int108
    .quad int109
    .quad int110
    .quad int111
    .quad int112
    .quad int113
    .quad int114
    .quad int115
    .quad int116
    .quad int117
    .quad int118
    .quad int119
    .quad int120
    .quad int121
    .quad int122
    .quad int123
    .quad int124
    .quad int125
    .quad int126
    .quad int127