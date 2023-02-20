#ifndef _OWL_AREA_H
#define _OWL_AREA_H 1

#include <stdint.h>

typedef struct {
  void* dataStart;
  uintptr_t dataSize;
  uintptr_t refs; /* When this is zero, we will destruct this object. (When freeing memory) */
} Area;

#endif