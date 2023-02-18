#include <arch/arch.h>
#include <alloc/alloc.h>
#include "sbi.h"

extern void* __memory_begin;
extern void* __memory_end;

void Rv64_EarlyInitialize() {
    Rv64_SBI_Initialize();
}

void Rv64_Initialize() {
    dealloc(&__memory_begin,((uintptr_t)&__memory_end)-((uintptr_t)&__memory_begin));
    LogInfo(Rv64_GetLogger(),"System has %i KiB of Heap Memory available.",(((uintptr_t)&__memory_end)-((uintptr_t)&__memory_begin))/1024);
}

void Rv64_WFI() { asm volatile("wfi"); }
int Stub() { return 0; }

const IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = Rv64_EarlyInitialize,
    .initialize = Rv64_Initialize,

    .disable_interrupts = Stub,
    .enable_interrupts = Stub,
    .halt = Rv64_WFI,

    .get_logger = Rv64_GetLogger,
    .get_framebuffer = Stub,
};