#include "SharedMemory.h"
#include "Syscall.h"

int64_t NewSharedMemory(size_t size) {
    return (int64_t)Syscall(0x30004,size,0,0,0,0,0);
}

void* MapSharedMemory(int64_t id) {
    return (void*)Syscall(0x30005,id,0,0,0,0,0);
}

void DestroySharedMemory(int64_t id) {
    Syscall(0x30006,id,0,0,0,0,0);
}