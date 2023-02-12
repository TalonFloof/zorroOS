#include "sbi.h"
#include <arch/arch.h>

void Rv64_SBI_Initialize() {
  // Check if the debug console extension is available, if not, use the legacy calls
  
}

void OwlRawLog_Legacy(const char* s, size_t c) {
  size_t i;
  for(i = 0; i < c; i++) {
    SBICallLegacy1(1,s[c]);
  }
}

void OwlRawLog_Modern(const char* s, size_t c) {
  SBICall3(0x4442434E,0,c,((uint64_t)s) & 0xFFFFFFFF,((uint64_t)s) >> 32);
}