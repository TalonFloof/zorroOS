#include <arch/arch.h>
#include "logger.h"

void x86_64_EarlyInitialize() {}

void x86_64_Initialize() {}

void x86_64_CLI() { asm volatile("cli"); }
void x86_64_STI() { asm volatile("sti"); }

IOwlArch owlArch = {
  .signature = 0x686372416c774f49,
  .initialize_early = x86_64_EarlyInitialize,
  .initialize = x86_64_Initialize,

  .disable_interrupts = x86_64_CLI,
  .enable_interrupts = x86_64_STI,

  .get_logger = x86_64_GetLogger,
};