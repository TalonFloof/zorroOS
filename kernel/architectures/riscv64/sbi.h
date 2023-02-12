#ifndef _RV64_SBI_H
#define _RV64_SBI_H 1
#include <stdint.h>

typedef enum {
    SBI_SUCCESS               =  0,
    SBI_ERR_FAILED            = -1,
    SBI_ERR_NOT_SUPPORTED     = -2,
    SBI_ERR_INVALID_PARAM     = -3,
    SBI_ERR_DENIED            = -4,
    SBI_ERR_INVALID_ADDRESS   = -5,
    SBI_ERR_ALREADY_AVAILABLE = -6
} SBIErrorCode;

typedef struct {
  SBIErrorCode error;
  uintptr_t value;
} SBIReturn;

static SBIReturn SBICall6(uintptr_t extID, uintptr_t funcID, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t arg4, uintptr_t arg5, uintptr_t arg6) {
  register uintptr_t a0 asm ("a0") = (uintptr_t)(arg1);
  register uintptr_t a1 asm ("a1") = (uintptr_t)(arg2);
  register uintptr_t a2 asm ("a2") = (uintptr_t)(arg3);
  register uintptr_t a3 asm ("a3") = (uintptr_t)(arg4);
  register uintptr_t a4 asm ("a4") = (uintptr_t)(arg5);
  register uintptr_t a5 asm ("a5") = (uintptr_t)(arg6);
  register uintptr_t a6 asm ("a6") = (uintptr_t)(funcID);
  register uintptr_t a7 asm ("a7") = (uintptr_t)(extID);
  asm volatile ("ecall" : "+r"(a0), "+r"(a1) : "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6), "r"(a7) : "memory");
  return (SBIReturn){
    .error = (SBIErrorCode)a0,
    .value = a1,
  };
}

#define SBICall0(extID, funcID) SBICall6(extID, funcID, 0, 0, 0, 0, 0, 0)
#define SBICall1(extID, funcID, arg1) SBICall6(extID, funcID, arg1, 0, 0, 0, 0, 0)
#define SBICall2(extID, funcID, arg1, arg2) SBICall6(extID, funcID, arg1, arg2, 0, 0, 0, 0)
#define SBICall3(extID, funcID, arg1, arg2, arg3) SBICall6(extID, funcID, arg1, arg2, arg3, 0, 0, 0)
#define SBICall4(extID, funcID, arg1, arg2, arg3, arg4) SBICall6(extID, funcID, arg1, arg2, arg3, arg4, 0, 0)
#define SBICall5(extID, funcID, arg1, arg2, arg3, arg4, arg5) SBICall6(extID, funcID, arg1, arg2, arg3, arg4, arg5, 0)

static intptr_t SBICallLegacy5(uintptr_t extID, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t arg4, uintptr_t arg5) {
  register uintptr_t a0 asm ("a0") = (uintptr_t)(arg1);
  register uintptr_t a1 asm ("a1") = (uintptr_t)(arg2);
  register uintptr_t a2 asm ("a2") = (uintptr_t)(arg3);
  register uintptr_t a3 asm ("a3") = (uintptr_t)(arg4);
  register uintptr_t a4 asm ("a4") = (uintptr_t)(arg5);
  register uintptr_t a7 asm ("a7") = (uintptr_t)(extID);
  asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a7) : "memory");
  return (intptr_t)a0;
}

#define SBICallLegacy0(extID) SBICallLegacy5(extID, 0, 0, 0, 0, 0)
#define SBICallLegacy1(extID, arg1) SBICallLegacy5(extID, arg1, 0, 0, 0, 0)
#define SBICallLegacy2(extID, arg1, arg2) SBICallLegacy5(extID, arg1, arg2, 0, 0, 0)
#define SBICallLegacy3(extID, arg1, arg2, arg3) SBICallLegacy5(extID, arg1, arg2, arg3, 0, 0)
#define SBICallLegacy4(extID, arg1, arg2, arg3, arg4) SBICallLegacy5(extID, arg1, arg2, arg3, arg4, 0)

void Rv64_SBI_Initialize();

#endif