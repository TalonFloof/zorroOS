#pragma once
#include <Panic.h>
#include <Utilities/String.h>

typedef struct {
  const char *name;
  char atomic;
  char permitInterrupts;
} Lock;

void Lock_Acquire(Lock *self) {
  int i;
  for (i = 0; i < 50000000; i++) {
    if (!__atomic_test_and_set(&(self->atomic), __ATOMIC_ACQUIRE)) {
      return;
    }
#ifdef __x86_64__
    asm volatile("pause");
#endif
  }
  char buffer[256];
  strcpy((char*)&buffer,"Detected Kernel Deadlock on Lock: ");
  strcpy(((char*)&buffer)+strlen(buffer),self->name);
  Panic((char*)&buffer);
}

static inline void Lock_Release(Lock *self) {
  __atomic_clear(&(self->atomic), __ATOMIC_RELEASE);
}