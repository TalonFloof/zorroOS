module x86_64

import framebuffer
import ksync
import arch

pub fn zorro_arch_initialize() {
	framebuffer.initialize()
}