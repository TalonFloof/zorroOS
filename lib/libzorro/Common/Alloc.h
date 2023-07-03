#ifndef _LIBZORRO_COMMON_ALLOC_H
#define _LIBZORRO_COMMON_ALLOC_H
#include <stdint.h>
#include <stddef.h>

#define PREFIX(func) func

extern void    *PREFIX(malloc)(size_t);
extern void    *PREFIX(realloc)(void *, size_t);
extern void    *PREFIX(calloc)(size_t, size_t);
extern void     PREFIX(free)(void *);

#endif