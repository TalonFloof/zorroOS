#include "IDT.h"
#include "Context.h"
#include "PortIO.h"
#include "Devices/PS2Mouse.h"
#include <Utilities/String.h>

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

void ExceptionHandler(int vector, ArchContext* context, int errcode) {
  
}

void IRQHandler(int vector, ArchContext* context) {
  if(vector == 0x21) {
    PS2MouseIRQ();
  } else if(vector == 0x2c) { /* PS/2 Mouse */
    PS2MouseIRQ();
  }
  if (vector >= 0x28)
    outb(0xA0, 0x20);
  outb(0x20, 0x20);
}

void IDT_Initialize() {
  int i;
  idtr.base = (uint64_t)&idt;
  idtr.limit = (uint16_t) sizeof(IDTEntry) * 256 - 1;
  for(i=0;i<256;i++) {
    IDT_Install(i,(&ISRTable)[i],0x8E);
  }
  asm volatile ("lidt %0" :: "m" (idtr));
  outb(0x20, 0x11);
  outb(0xA0, 0x11);
  outb(0x21, 0x20);
  outb(0xA1, 0x28);
  outb(0x21, 0x04);
  outb(0xA1, 0x02);
  outb(0x21, 0x01);
  outb(0xA1, 0x01);
  outb(0x21, 0x01);
  outb(0xA1, 0x10);
  asm volatile ("sti");
}