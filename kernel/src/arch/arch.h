#ifndef _OWL_ARCH_H
#define _OWL_ARCH_H 1

#include <stdint.h>

#include "interfaces/framebuffer.h"

typedef void (*IOwlArch_NoArgFn)(void);

typedef struct {
  uint64_t signature; /* Set to "IOwlArch", 0x686372416c774f49 */

  IOwlArch_NoArgFn initialize_early;
  IOwlArch_NoArgFn initialize;

  IOwlArch_NoArgFn disable_interrupts;
  IOwlArch_NoArgFn enable_interrupts;
} IOwlArch;

extern IOwlArch owlArch;

#endif