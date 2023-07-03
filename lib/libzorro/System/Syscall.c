#include "Syscall.h"
#include "../Filesystem/Filesystem.h"

SyscallCode Syscall(uintptr_t call, uintptr_t a0,uintptr_t a1,uintptr_t a2,uintptr_t a3,uintptr_t a4,uintptr_t a5) {
#ifdef _LIBZORRO_TARGET_X86_64
    SyscallCode ret;
    register uintptr_t reg3 asm("r10") = a3;
    register uintptr_t reg4 asm("r8") = a4;
    register uintptr_t reg5 asm("r9") = a5;
    asm volatile("syscall"
                 : "=a"(ret)
                 : "a"(call), "D"(a0), "S"(a1), "d"(a2), "r"(reg3), "r"(reg4), "r"(reg5)
                 : "memory", "r11", "rcx");
    return ret;
#else
// #error "Current Architecture is unsupported"
    return 0;
#endif
}

void* MMap(void* addr, size_t length, int prot, int flags, int64_t fd, off_t offset) {
    return (void*)Syscall(0x10011,(uintptr_t)addr,length,prot,flags,fd,offset);
}

void MUnMap(void* addr, size_t length) {
    Syscall(0x10012,(uintptr_t)addr,length,0,0,0,0);
}

SyscallCode RyuLog(const char* s) {
    return Syscall(0x30001,(uintptr_t)s,0,0,0,0,0);
}