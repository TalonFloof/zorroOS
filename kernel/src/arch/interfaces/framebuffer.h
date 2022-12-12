#ifndef _KZORRO_IFRAMEBUFFER_H
#define _KZORRO_IFRAMEBUFFER_H 1

#include <stdint.h>

/*
pub interface IZorroFramebuffer {
    get_resolution() ZorroFramebufferResolution
    get_depth() u8
    get(int,int) u32
    get_unsafe_pointer() &u8
    set(int,int,u32)
}*/

typedef struct
{
    uint64_t signature; /* "IZorroFB", or 0x42466f72726f5a49 */
} IZorroFramebuffer;

#endif