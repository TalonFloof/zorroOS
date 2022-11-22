module main

import arch.x86_64
import arch
import panic

pub fn main() { // To make the V compiler shut up.
	zorro_kernel_main()
}

pub fn zorro_kernel_main() {
	x86_64.zorro_arch_initialize()
	panic.panic(panic.ZorroPanicCategory.ramdisk,"No Ramdisk")
}