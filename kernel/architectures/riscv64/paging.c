#include <arch/arch.h>
#include <alloc/alloc.h>

typedef struct {
  uint64_t valid : 1;
  uint64_t read : 1;
  uint64_t write : 1;
  uint64_t execute : 1;
  uint64_t user : 1;
  uint64_t global : 1;
  uint64_t accessed : 1;
  uint64_t dirty : 1;
  uint64_t rsw : 2;
  uint64_t ppn : 44;
  uint64_t reserved : 7;
  uint64_t memType : 2;
  uint64_t napot : 1;
} PageTableEntry;

void OwlMapPage(OwlAddressSpace* addrSpace, uintptr_t vaddr, uintptr_t paddr, int flags) {
  PageTableEntry* pageTable = addrSpace->pageTableBase;
  int level = 3-((flags & (PGFLAG_SIZE1 | PGFLAG_SIZE2 | PGFLAG_SIZE3)) >> 6);
  int i;
  for(i=0;i < level;i++) {
    uintptr_t index = (vaddr & (0x7FC0000000 >> (i*9))) >> (30-(i*9));
    if(!pageTable[index].valid) {
      if(i+1 < level) {
        PageTableEntry* newPageTable = alloc(4096,4096);
        pageTable[index].valid = 1;
        pageTable[index].read = 0;
        pageTable[index].write = 0;
        pageTable[index].execute = 0;
        pageTable[index].user = (flags & PGFLAG_USER) >> 3;
        pageTable[index].global = 0;
        pageTable[index].napot = 0;
        pageTable[index].memType = 0;
        pageTable[index].ppn = ((uint64_t)newPageTable) >> 12;
        pageTable = newPageTable;
      } else if(i+1 >= level) {
        if(flags & PGFLAG_READ) {
          pageTable[index].valid = 1;
          pageTable[index].read = 1;
          pageTable[index].write = (flags & PGFLAG_WRITE)?1:0;
          pageTable[index].execute = (flags & PGFLAG_EXECUTE)?1:0;
          pageTable[index].user = (flags & PGFLAG_USER)?1:0;
          pageTable[index].global = 0;
          pageTable[index].ppn = paddr >> 12;
          pageTable[index].memType = (flags & PGFLAG_WRITETHROUGH)?2:((flags & PGFLAG_UNCACHED)?1:0);
          pageTable[index].napot = 0;
          return;
        } else {
          pageTable[index].valid = 0;
          return;
        }
      } else {
        return;
      }
    } else {
      if(i+1 >= level && !(flags & PGFLAG_READ)) { /* Unmap Page */
        pageTable[index].valid = 0;
        return;
      }
      if(i+1 >= level || (pageTable[index].read || pageTable[index].write || pageTable[index].execute)) /* Cannot Map Page */
        return;
      pageTable = (PageTableEntry*)(pageTable[index].ppn << 12);
    }
  }
}

void OwlMapPages(void* ptr, uintptr_t vaddr, uintptr_t paddr, size_t pages, int flags) {
  OwlAddressSpace* addrSpace = (OwlAddressSpace*)ptr;
  vaddr = vaddr & 0x7FFFFFF000;
  paddr = paddr & (~0xFFF);
  size_t i;
  for(i=0; i < pages; i++) {
    OwlMapPage(addrSpace,vaddr,paddr,flags);
    vaddr += 4096;
    paddr += 4096;
  }
}

void OwlSetActiveSpace(void* ptr) {
  register uintptr_t t0 asm ("t0") = ((uintptr_t)ptr) | (8 << 60);
  asm volatile("csrw satp, t0" :: "r"(t0));
}