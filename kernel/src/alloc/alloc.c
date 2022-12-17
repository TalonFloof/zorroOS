#include "alloc.h"

Lock owlAllocationLock = {
    .name = "Owl Allocation Lock",
    .atomic = 0,
    .permitInterrupts = 0,
};