#include "Filesystem.h"

int64_t Open(const char* path, int mode) {
    return (int64_t)Syscall(0x10001,(uintptr_t)path,mode,0,0,0,0);
}

SyscallCode Close(int64_t fd) {
    return Syscall(0x10002,(uintptr_t)fd,0,0,0,0,0);
}

size_t Read(int64_t fd, void* base, size_t size) {
    return (size_t)Syscall(0x10003,(uintptr_t)fd,(uintptr_t)base,size,0,0,0);
}

size_t ReadDir(int64_t fd, intptr_t offset, void* base) {
    return (int64_t)Syscall(0x10004,(uintptr_t)fd,(uintptr_t)offset,(uintptr_t)base,0,0,0);
}

size_t Write(int64_t fd, void* base, size_t size) {
    return (size_t)Syscall(0x10005,(uintptr_t)fd,(uintptr_t)base,size,0,0,0);
}