#include <arch/arch.h>
#include <alloc/alloc.h>
#include "sbi.h"
#include "paging.h"

extern void* __memory_begin;
extern void* __memory_end;
extern void* rv64_boot_page_table;

void Rv64_EarlyInitialize() {
    Rv64_SBI_Initialize();
}

void Rv64_Initialize() {
    dealloc(&__memory_begin,((uintptr_t)&__memory_end)-((uintptr_t)&__memory_begin));
    LogInfo(Rv64_GetLogger(),"System has %i KiB of Heap Memory available.",(((uintptr_t)&__memory_end)-((uintptr_t)&__memory_begin))/1024);
}

void Rv64_WFI() { asm volatile("wfi"); }
int Stub() { return 0; }

OwlAddressSpace kspace = {
    .pageTableBase = (void*)&rv64_boot_page_table,
    .map = OwlMapPages,
    .setActive = OwlSetActiveSpace,
    .free = OwlFreeSpace,
};

OwlAddressSpace* Rv64_CreateAddrSpace() {
    OwlAddressSpace* space = malloc(sizeof(OwlAddressSpace));
    space->pageTableBase = alloc(4096,4096);
    space->map = OwlMapPages;
    space->setActive = OwlSetActiveSpace;
    space->free = OwlFreeSpace;
    return space;
}

OwlAddressSpace* Rv64_GetKernelSpace() { return &kspace; }

const IOwlArch owlArch = {
    .signature = 0x686372416c774f49,
    .initialize_early = Rv64_EarlyInitialize,
    .initialize = Rv64_Initialize,

    .disable_interrupts = Stub,
    .enable_interrupts = Stub,
    .halt = Rv64_WFI,

    .get_logger = Rv64_GetLogger,
    .get_framebuffer = Stub,
    .create_addrspace = Rv64_CreateAddrSpace,
    .get_kernspace = Rv64_GetKernelSpace,
};