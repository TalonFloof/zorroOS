#include <sync/lock.h>

void Lock_Acquire(Lock *self) {
  int i;
  for (i = 0; i < 50000000; i++) {
    if (!__atomic_test_and_set(&(self->atomic), __ATOMIC_ACQUIRE)) {
      return;
    }
#ifdef _OWL_ARCH_X86_64
    asm volatile("pause");
#endif
  }
  const char* lines[2] = {"Detected Kernel Deadlock!",self->name};
  PanicMultiline(PANIC_GENERIC,(const char**)&lines,2);
}

inline void Lock_Release(Lock *self) {
  __atomic_clear(&(self->atomic), __ATOMIC_RELEASE);
}