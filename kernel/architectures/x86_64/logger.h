#ifndef _X86_64_LOGGER_H
#define _X86_64_LOGGER_H

#include <arch/arch.h>
#include "limine.h"

static volatile struct limine_terminal_request limine_terminal_request = {
    .id = LIMINE_TERMINAL_REQUEST,
    .revision = 0
};

void OwlRawLog(const char* s, size_t c) {
  limine_terminal_request.response->write(limine_terminal_request.response->terminals[0],s,(uint64_t)c);
}

IOwlLogger x86_64_GetLogger() {
  return OwlRawLog;
}

#endif