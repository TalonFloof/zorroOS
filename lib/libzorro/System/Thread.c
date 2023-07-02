#include "Thread.h"
#include "Syscall.h"

void Yield() {
    Syscall(0x20001,0,0,0,0,0,0);
}

void Exit(int code) {
    Syscall(0x20002,code,0,0,0,0,0);
}