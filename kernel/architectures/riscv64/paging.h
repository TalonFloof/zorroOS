#ifndef _RV64_PAGING_H
#define _RV64_PAGING_H 1
#include <arch/arch.h>
#include <stdint.h>

void OwlMapPages(void* ptr, uintptr_t vaddr, uintptr_t paddr, size_t pages, int flags);
void OwlSetActiveSpace(void* ptr);
void OwlFreeSpace(void* ptr);

#endif