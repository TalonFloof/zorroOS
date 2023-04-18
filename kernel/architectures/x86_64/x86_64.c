#include <stdint.h>
#include <Graphics/Framebuffer.h>
#include "FB.h"
#include "IDT.h"
#include "Devices/PS2Mouse.h"

void Arch_EarlyInitialize() {
  Limine_InitFB();
}

void Arch_Initialize() {
  IDT_Initialize();
  PS2MouseInit();
}

void Arch_ClearScreen() {
  Limine_ClearScreen();
}

void Arch_Halt() {
  asm volatile ("hlt");
}

void Arch_IRQEnableDisable(int enabled) {
  if(enabled) {
    asm volatile("sti");
  } else {
    asm volatile("cli");
  }
}