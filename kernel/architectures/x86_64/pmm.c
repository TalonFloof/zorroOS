#include "limine.h"

#include "limine.h"
#include "pmm.h"
#include <alloc/alloc.h>

static volatile struct limine_memmap_request limine_memmap_request = {
  .id = LIMINE_MEMMAP_REQUEST,
  .revision = 0
};

void x86_64_PMM_Initialize() {
  IOwlLogger logger = owlArch.get_logger();
  struct limine_memmap_entry **entries = limine_memmap_request.response->entries;
  uint64_t ind;
  for(ind = 0; ind < limine_memmap_request.response->entry_count; ind++) {
    const char* entry_type = "Unknown (Bootloader Bug?)";
    switch(entries[ind]->type) {
      case 0:
        entry_type = "Usable";
        dealloc(((void*)entries[ind]->base), entries[ind]->length);
        break;
      case 1:
        entry_type = "Reserved";
        break;
      case 2:
        entry_type = "ACPI Reclaimable";
        break;
      case 3:
        entry_type = "ACPI NVS";
        break;
      case 4:
        entry_type = "Bad Memory";
        break;
      case 5:
        entry_type = "Bootloader Reclaimable";
        break;
      case 6:
        entry_type = "Kernel and Modules";
        break;
      case 7:
        entry_type = "Framebuffer";
        break;
    }
    LogDebug(logger, "Memory map entry No. %i: Base: %x | Length: %x | Type: %s", ind, entries[ind]->base, entries[ind]->length, entry_type);
  }
}