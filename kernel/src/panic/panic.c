#include "panic.h"

#include <arch/arch.h>

#include "panic_images.h"

__attribute__((noreturn)) void PanicMultiline(OwlPanicCategory category,
                                              const char** msgs, int len) {
  IOwlLogger logger = owlArch.get_logger();
  if (logger != 0) {
    if (category != PANIC_RAMDISK && category != PANIC_INVALID_SETUP) {
        }
  }
  /* Now to draw something to the framebuffer */
  for (;;) {
  }
}