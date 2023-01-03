#ifndef _X86_64_FRAMEBUFFER_H
#define _X86_64_FRAMEBUFFER_H

#include <arch/arch.h>
#include "limine.h"

void x86_64_FBInit();

IOwlFramebuffer* x86_64_GetFramebuffer();

#endif