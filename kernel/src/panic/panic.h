#ifndef _OWL_PANIC_H
#define _OWL_PANIC_H 1

typedef enum {
  PANIC_GENERIC = 1,
  PANIC_INCOMPATABLE_HARDWARE = 2,
  PANIC_OUT_OF_MEMORY = 3,
  PANIC_RAMDISK = 4,
  PANIC_INVALID_SETUP = 5,
} OwlPanicCategory;

__attribute__((noreturn)) void Panic(const char* msg);
__attribute__((noreturn)) void PanicMultiline(OwlPanicCategory category,
                                              const char** msgs, int len);
__attribute__((noreturn)) void PanicCat(OwlPanicCategory category, const char* msg);

#endif