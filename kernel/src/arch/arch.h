#ifndef _OWL_ARCH_H
#define _OWL_ARCH_H 1

#include <stdint.h>
#include "interfaces/framebuffer.h"

typedef void (*IOwlArch_Init)(void);

typedef struct
{
    uint64_t signature; /* Set to "IOwlArch", 0x686372416c774f49 */

    IOwlArch_Init initialize_early;
    IOwlArch_Init initialize;

} IOwlArch;

extern IOwlArch owlArch;

#endif