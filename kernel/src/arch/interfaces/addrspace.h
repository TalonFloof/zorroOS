#ifndef _OWL_IADDRSPACE_H

#include <stdint.h>

typedef enum {
  PGFLAG_READ = 1, /* If this is unset, then the page will be unmapped */
  PGFLAG_WRITE = 2,
  PGFLAG_EXECUTE = 4,
  PGFLAG_USER = 8,
} PageFlags;

typedef void (*IOwlAddrSpace_Map)(uintptr_t, uintptr_t, int, int);

typedef struct {
  void* pageTableBase;
  IOwlAddrSpace_Map map;
} OwlAddressSpace;

#endif