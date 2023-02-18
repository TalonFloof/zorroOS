#include <arch/arch.h>
#include <alloc/alloc.h>

void OwlMapPages(void* ptr, uintptr_t vaddr, uintptr_t paddr, size_t pages, int flags) {
  OwlAddressSpace* addrSpace = (OwlAddressSpace*)ptr;
  vaddr = vaddr & 0xFFFFFFFFFF;
  
}

void OwlMapPage(OwlAddressSpace* addrSpace, uintptr_t vaddr, uintptr_t paddr, int flags) {
  uint64_t* pageTable = addrSpace->pageTableBase;
  int level = 3-((flags & (PGFLAG_SIZE1 | PGFLAG_SIZE2 | PGFLAG_SIZE3)) >> 5)
  int i;
  for(i=0;i < level;i++) {
    
  }
}