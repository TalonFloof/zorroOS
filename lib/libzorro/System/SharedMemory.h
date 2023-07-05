#ifndef _LIBZORRO_SYSTEM_SHAREDMEMORY_H
#define _LIBZORRO_SYSTEM_SHAREDMEMORY_H
#include <stdint.h>
#include <stddef.h>

int64_t NewSharedMemory(size_t size);
void* MapSharedMemory(int64_t id);
void DestroySharedMemory(int64_t id);

#endif