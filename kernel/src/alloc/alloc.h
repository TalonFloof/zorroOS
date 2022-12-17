#ifndef _OWL_ALLOC_H
#define _OWL_ALLOC_H 1

#include <stdint.h>
#include <sync/lock.h>

typedef enum {
  NO_ALLOCATOR = 0,
  LINKED_LIST_ALLOCATOR = 1,
} OwlAllocatorTypes;

#define OWL_DEFAULT_ALLOCATOR                                                  \
  LINKED_LIST_ALLOCATOR /* You can change this to a different allocator if you \
                           want to. */

extern void *alloc(uintptr_t n, uintptr_t align);
extern void dealloc(void *ptr, uintptr_t n, uintptr_t align);

extern void *malloc(uintptr_t n);
extern void free(void *ptr);

#endif