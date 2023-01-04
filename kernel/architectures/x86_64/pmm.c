#include "limine.h"

#include "limine.h"

static volatile struct limine_memmap_request limine_memmap_request = {
  .id = LIMINE_MEMMAP_REQUEST,
  .revision = 0
};