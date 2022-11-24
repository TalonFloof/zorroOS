module x86_64

import framebuffer
import alloc
import pmm
import cpu

pub fn (a &Arch) initialize_early() {
	framebuffer.initialize()
	pmm.initialize()
}

pub fn (a &Arch) initialize() {
	cpu.initialize_gdt()
	//hi := [1,2,3,4] // Testing Memory Allocation
}