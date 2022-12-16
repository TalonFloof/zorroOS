#include <arch/arch.h>

IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = x86_64_EarlyInitialize,
    .initialize = x86_64_Initialize,
};

void x86_64_EarlyInitialize()
{
}

void x86_64_Initialize()
{
}