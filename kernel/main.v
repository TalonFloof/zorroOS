module main

import arch.x86_64
import arch
import panic

pub fn main() { // To make the V compiler shut up.
	zorro_kernel_main()
}

fn C._vinit(argc int, argv voidptr)

pub fn zorro_kernel_main() {
	zorro_arch.initialize_early()
	//C._vinit(0, 0)
	logger := zorro_arch.get_logger() or { panic("Couldn't get logger") }
	logger.info("Zorro Kernel")
	logger.info("Copyright (C) 2020-2022 TalonFox and contributors")
	zorro_arch.initialize()
	panic.panic(panic.ZorroPanicCategory.ramdisk,"No Ramdisk")
}