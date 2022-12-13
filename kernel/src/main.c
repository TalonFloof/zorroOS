/*
Original V Code:
module main

import arch.x86_64
import arch
import alloc

pub fn main() { // To make the V compiler shut up.
    zorro_kernel_main()
}
z
fn C._vinit(argc int, argv voidptr)

pub fn zorro_kernel_main() {
    arch.IZorroArch(zorro_arch).initialize_early() // The casting acts as a checker to see if the architecture implementation complies with the IZorroArch interface.
    C._vinit(0, 0)
    logger := zorro_arch.get_logger() or { panic("Couldn't get logger") }
    logger.info("Zorro Kernel")
    logger.info("Copyright (C) 2020-2022 TalonFox and contributors")
    zorro_arch.initialize()
    zorro_arch.halt()
    //logger.error("No ramdisk was provided, cannot continue boot!")
    //panic.panic(panic.ZorroPanicCategory.ramdisk,"No Ramdisk")
}
*/

#include <stdint.h>
#ifdef _ZORRO_ARCH_X86_64
#include "arch/x86_64/x86_64.h"
#endif
#include "arch/arch.h"

void ZorroKernelMain()
{
    /* Ensure that the IZorroArch signature is present */
    if (zorroArch.signature != 0x72416f72726f5a49)
    {
        /* The kernel cannot properly operate without a valid IZorroArch Implementation, Halt Hart 0x00 */
        while (1)
        {
        };
    }
    zorroArch.initialize_early(); /* Initialize some early architectural features that are immediately needed at boot. */
}