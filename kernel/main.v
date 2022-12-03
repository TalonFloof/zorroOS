module main

import arch.x86_64
import arch
import alloc

pub fn main() { // To make the V compiler shut up.
	zorro_kernel_main()
}

fn C._vinit(argc int, argv voidptr)

pub fn zorro_kernel_main() {
	alloc.init_workaround()
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