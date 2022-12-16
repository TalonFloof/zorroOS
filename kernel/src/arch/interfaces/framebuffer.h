#ifndef _OWL_IFRAMEBUFFER_H
#define _OWL_IFRAMEBUFFER_H 1

#include <stdint.h>

typedef uint32_t (*IOwlFramebuffer_Get)(int, int);
typedef void (*IOwlFramebuffer_Set)(int, int, uint32_t);

typedef struct
{
    uint64_t signature; /* "IOwlFrBf", or 0x42466f72726f5a49 */
    int resolution[2];
    uint8_t depth;
    void *pointer;
    IOwlFramebuffer_Get get;
    IOwlFramebuffer_Set set;
} IOwlFramebuffer;

#endif