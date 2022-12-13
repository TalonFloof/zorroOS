#ifndef _KZORRO_ARCH_H
#define _KZORRO_ARCH_H 1

#include <stdint.h>
#include "interfaces/framebuffer.h"
#include "interfaces/framebuffer.h"

typedef void (*IZorroArch_Init)(void);

typedef struct
{
    uint64_t signature; /* Set to "IZorroAr", 0x72416f72726f5a49 */

    IZorroArch_Init initialize_early;
    IZorroArch_Init initialize;

} IZorroArch;

extern IZorroArch zorroArch;

#endif