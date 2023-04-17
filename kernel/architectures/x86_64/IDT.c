#include "IDT.h"
#include <Misc.h>

static IDTEntry idt[256];
static IDTP idtr;

void IDT_Initialize() {
  SetCurrentStatus("Loading IDT...");
}