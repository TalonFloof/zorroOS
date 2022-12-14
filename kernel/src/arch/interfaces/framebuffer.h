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

typedef uint32_t (*IZorroArch_Get)(int, int);
typedef void (*IZorroArch_Set)(int, int, uint32_t);

typedef struct
{
    uint64_t signature; /* "IZorroFB", or 0x42466f72726f5a49 */
    int resolution[2];
    uint8_t depth;
    void *pointer;
    IZorroArch_Get get;
    IZorroArch_Set set;
} IZorroFramebuffer;

#endif