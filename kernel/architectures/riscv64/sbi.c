#include "sbi.h"
#include <arch/arch.h>

int OwlUseLegacyConsole = 1;

void Rv64_SBI_Initialize() {
  // Check if the debug console extension is available, if not, use the legacy calls
  SBIReturn hasDebugCon = SBICall1(0x10,3,0x4442434E);
  if(hasDebugCon.value) {
    OwlUseLegacyConsole = 0;
  } else {
    // We'll have to use the legacy console
    IOwlLogger logger = Rv64_GetLogger();
    LogWarn(logger,"This SBI implementation doesn't support the DBCN extension. We're using the legacy calls, but these are planned to be removed!");
  }
}

void OwlRawLog_Legacy(const char* s, size_t c) {
  size_t i;
  for(i = 0; i < c; i++) {
    SBICallLegacy1(1,s[i]);
  }
}

void OwlRawLog_Modern(const char* s, size_t c) {
  SBICall3(0x4442434E,0,c,s,0);
}

IOwlLogger Rv64_GetLogger() {
  return OwlUseLegacyConsole ? OwlRawLog_Legacy : OwlRawLog_Modern;
}