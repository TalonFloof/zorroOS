#ifndef _LIBZORRO_SYSTEM_SYSCALL_H
#define _LIBZORRO_SYSTEM_SYSCALL_H
#include <stdint.h>
#include <stddef.h>
#include "../Filesystem/Filesystem.h"

typedef intptr_t SyscallCode;

#define MAP_PRIVATE 0x1
#define MAP_SHARED 0x2
#define MAP_FIXED 0x4
#define MAP_ANONYMOUS 0x8

SyscallCode Syscall(uintptr_t call, uintptr_t a0,uintptr_t a1,uintptr_t a2,uintptr_t a3,uintptr_t a4,uintptr_t a5);
void* MMap(void* addr, unsigned long length, int prot, int flags, int64_t fd, intptr_t offset);
void MUnMap(void* addr, size_t length);
SyscallCode RyuLog(const char* s);

#endif