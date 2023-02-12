#include <arch/arch.h>
#include "sbi.h"

void Rv64_EarlyInitialize() {
    Rv64_SBI_Initialize();
}

void Rv64_Initialize() {
}

void Rv64_WFI() { asm volatile("wfi"); }

const IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = Rv64_EarlyInitialize,
    .initialize = Rv64_Initialize,

    .disable_interrupts = Rv64_IntrOff,
    .enable_interrupts = Rv64_IntrOn,
    .halt = Rv64_WFI,
};