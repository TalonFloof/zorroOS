#include "Thread.h"
#include "Syscall.h"

void Exit(int code) {
    Syscall(0x20001,code,0,0,0,0,0);
}

ThreadID NewThread(const char* name, void* ip, void* sp) {
    return Syscall(0x20006,(uintptr_t)name,(uintptr_t)ip,(uintptr_t)sp,0,0,0);
}

void Eep(int ms) {
    Syscall(0x20010,ms,0,0,0,0,0);
}