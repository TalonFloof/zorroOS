#pragma once
#include <stdint.h>

#define REG_SP 256
#define REG_IP 257

typedef uintptr_t (*IContext_GetRegister)(int);
typedef void (*IContext_SetRegister)(int,uintptr_t);

typedef struct {
  IContext_GetRegister getReg;
  IContext_SetRegister setReg;
  void* context; /* This isn't actually a pointer, rather it marks the start of the ArchContext struct */
} IContext;