#include <stdint.h>
#include <Graphics/Framebuffer.h>
#include "FB.h"
#include "IDT.h"

void Arch_EarlyInitialize() {
  Limine_InitFB();
}

void Arch_Initialize() {
  IDT_Initialize();
}

void Arch_ClearScreen() {
  Limine_ClearScreen();
}

void Arch_Halt() {
  for(;;) {
    asm volatile ("cli");
    asm volatile ("hlt");
  }
}