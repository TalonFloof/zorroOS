#include <arch/arch.h>

void x86_64_EarlyInitialize()
{
}

void x86_64_Initialize()
{
}

IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = x86_64_EarlyInitialize,
    .initialize = x86_64_Initialize,
};