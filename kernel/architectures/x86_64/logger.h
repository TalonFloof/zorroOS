#ifndef _X86_64_LOGGER_H
#define _X86_64_LOGGER_H

#include <arch/arch.h>
#include "limine.h"
#include "pio.h"

static volatile struct limine_terminal_request limine_terminal_request = {
    .id = LIMINE_TERMINAL_REQUEST,
    .revision = 0
};

void x86_64_Log_Initialize() {
  out8(0x3F8 + 1, 0x00);
  out8(0x3F8 + 3, 0x80);
  out8(0x3F8 + 0, 0x03);
  out8(0x3F8 + 1, 0x00);
  out8(0x3F8 + 3, 0x03);
  out8(0x3F8 + 2, 0xC7);
  out8(0x3F8 + 4, 0x0B);
}

void OwlRawLog(const char* s, size_t c) {
  limine_terminal_request.response->write(limine_terminal_request.response->terminals[0],s,(uint64_t)c);
  size_t i;
  for(i = 0; i < c; i++) {
    out8(0x3F8,s[i]);
  }
}

IOwlLogger x86_64_GetLogger() {
  return OwlRawLog;
}

#endif