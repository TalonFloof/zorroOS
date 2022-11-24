module x86_64

import framebuffer
import ksync
import arch
import panic
import alloc

pub fn (a &Arch) initialize_early() {
	framebuffer.initialize()
	alloc.early_init()
}

pub fn (a &Arch) initialize() {
	
}