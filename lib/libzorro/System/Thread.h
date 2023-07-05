#ifndef _LIBZORRO_SYSTEM_THREAD_H
#define _LIBZORRO_SYSTEM_THREAD_H
#include "Syscall.h"

typedef int64_t ThreadID;

void Exit(int code);
ThreadID NewThread(const char* name, void* ip, void* sp);
void Eep(int ms);
#endif