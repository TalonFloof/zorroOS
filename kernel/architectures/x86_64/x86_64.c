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