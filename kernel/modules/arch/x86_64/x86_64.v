module x86_64

import limine
import framebuffer
import panic

pub fn zorro_arch_initialize() {
	framebuffer.initialize()
	panic.panic(panic.ZorroPanicCategory.ramdisk,"No Ramdisk")
}