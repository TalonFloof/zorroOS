#ifndef _LIBZORRO_COMMON_SPINLOCK_H
#define _LIBZORRO_COMMON_SPINLOCK_H

static void SpinlockAcquire(char *a) {
  while(1) {
    if (!__atomic_test_and_set(a, __ATOMIC_ACQUIRE)) {
      return;
    }
#ifdef _LIBZORRO_TARGET_X86_64
    asm volatile("pause");
#endif
  }
}

static inline void SpinlockRelease(char *a) {
  __atomic_clear(a, __ATOMIC_RELEASE);
}

#endif