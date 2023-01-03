#include <arch/arch.h>

IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = RiscV64_EarlyInitialize,
    .initialize = RiscV64_Initialize,
};

void RiscV64_EarlyInitialize() {
}

void RiscV64_Initialize() {
}