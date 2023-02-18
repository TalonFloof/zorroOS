#ifndef _OWL_IADDRSPACE_H

#include <stdint.h>

typedef enum {
  PGFLAG_READ = 1, /* If this is unset, then the page will be unmapped */
  PGFLAG_WRITE = 2,
  PGFLAG_EXECUTE = 4,
  PGFLAG_USER = 8,
  PGFLAG_UNCACHED = 16,
  PGFLAG_WRITETHROUGH = 32,
  PGFLAG_SIZE1 = 64,
  PGFLAG_SIZE2 = 128,
  PGFLAG_SIZE3 = 256,
} PageFlags;

typedef int (*IOwlAddrSpace_Map)(void*, uintptr_t, uintptr_t, size_t, int);
typedef void (*IOwlAddrSpace_Switch)(void*);
typedef void (*IOwlAddrSpace_Free)(void*);

typedef struct {
  void* pageTableBase;
  IOwlAddrSpace_Map map;
  IOwlAddrSpace_Switch setActive;
  IOwlAddrSpace_Free free;
} OwlAddressSpace;

#endif