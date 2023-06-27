.section .text

.extern __entry
.global _start
.type _start, @function
_start:
    call __entry
    ud2