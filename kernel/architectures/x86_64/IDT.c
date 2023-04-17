#include "IDT.h"
#include <Misc.h>

static IDTEntry idt[256];
static IDTP idtr;

extern void* ISRTable;

void IDT_Install(unsigned char entry, void* isr, unsigned char flags) {
  IDTEntry* desc = &idt[entry];
  desc->kernelCS = 0x28;
  desc->attributes = flags;
  desc->zero = 0;
  desc->reserved = 0;
  desc->isrLow = ((uintptr_t)isr) & 0xFFFF;
  desc->isrMid = (((uintptr_t)isr) >> 16) & 0xFFFF;
  desc->isrHigh = (((uintptr_t)isr) >> 32) & 0xFFFFFFFF;
}

void IRQHandler() {
  
}

void IDT_Initialize() {
  int i;
  idtr.base = (uint64_t)&idt;
  idtr.limit = (uint16_t) sizeof(IDTEntry) * 256 - 1;
  SetCurrentStatus("Loading IDT...");
  for(i=0;i<256;i++) {
    IDT_Install(i,(&ISRTable)[i],0x8E);
  }
  asm volatile ("lidt %0" :: "m" (idtr));
  asm volatile ("sti");
}