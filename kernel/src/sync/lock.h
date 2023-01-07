#ifndef _OWL_LOCK_H
#define _OWL_LOCK_H 1

#include <arch/arch.h>
#include <panic/panic.h>

typedef struct {
  const char *name;
  char atomic;
  char permitInterrupts;
} Lock;

inline void Lock_Acquire(Lock *self);

inline void Lock_Release(Lock *self);

#endif