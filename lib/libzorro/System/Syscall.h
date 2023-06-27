#ifndef _LIBZORRO_SYSTEM_SYSCALL_H
#define _LIBZORRO_SYSTEM_SYSCALL_H
#include <stdint.h>

typedef intptr_t SyscallCode;

SyscallCode RyuLog(const char* s);

#endif