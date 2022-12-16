#ifndef _OWL_ALLOC_H
#define _OWL_ALLOC_H 1

#include <stddef.h>

typedef enum
{
    LINKED_LIST_ALLOCATOR = 0,
} OwlAllocatorTypes;

#define OWL_DEFAULT_ALLOCATOR LINKED_LIST_ALLOCATOR /* You can change this to a different allocator if you want to. */

extern void *malloc(size_t size);
extern void free(void *ptr);

#endif