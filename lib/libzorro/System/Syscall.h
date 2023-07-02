#ifndef _LIBZORRO_SYSTEM_SYSCALL_H
#define _LIBZORRO_SYSTEM_SYSCALL_H
#include <stdint.h>
#include <stddef.h>
#include "../Filesystem/Filesystem.h"

typedef intptr_t SyscallCode;

SyscallCode Syscall(uintptr_t call, uintptr_t a0,uintptr_t a1,uintptr_t a2,uintptr_t a3,uintptr_t a4,uintptr_t a5);
void* MMap(void* addr, unsigned long length, int prot, int flags, int64_t fd, intptr_t offset);
SyscallCode RyuLog(const char* s);

#endif