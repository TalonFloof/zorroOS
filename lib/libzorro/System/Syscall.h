#ifndef _LIBZORRO_SYSTEM_SYSCALL_H
#define _LIBZORRO_SYSTEM_SYSCALL_H
#include <stdint.h>

typedef intptr_t SyscallCode;

SyscallCode Syscall(uintptr_t call, uintptr_t a0,uintptr_t a1,uintptr_t a2,uintptr_t a3,uintptr_t a4,uintptr_t a5);
SyscallCode RyuLog(const char* s);

#endif