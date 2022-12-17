#ifndef _OWL_LOCK_H
#define _OWL_LOCK_H 1

#include <arch/arch.h>

typedef struct {
  const char *name;
  char atomic;
  char permitInterrupts;
} Lock;

static inline void Lock_Acquire(Lock *self) {
  int i;
  for (i = 0; i < 50000000; i++) {
    if (__atomic_test_and_set(&self->atomic, __ATOMIC_ACQUIRE)) {
      return;
    }
#ifdef _OWL_ARCH_X86_64
    asm volatile("pause");
#endif
  }
  /* TODO: Implement Panic Routine */
  /*
        logger := zorro_arch.get_logger() or { unsafe { goto panic_routine }
return } logger.log(log.ZorroLogLevel.fatal,"Detected Deadlock on KLock:
\"",false) logger.raw_log(l.id) logger.raw_log("\"\n") panic_routine: arr :=
["Kernel is Deadlocked!",l.id]! unsafe {
                panic.panic_multiline(panic.ZorroPanicCategory.generic,&string(&arr),2)
        }
  */
}

static inline void Lock_Release(Lock *self) {
  __atomic_clear(self, __ATOMIC_RELEASE);
}

#endif