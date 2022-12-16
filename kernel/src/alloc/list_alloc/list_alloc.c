#include <alloc/alloc.h>

#if OWL_DEFAULT_ALLOCATOR == LINKED_LIST_ALLOCATOR

void *malloc(size_t size)
{
}

void free(void *ptr)
{
}

#endif