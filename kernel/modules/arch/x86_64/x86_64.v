module x86_64

import limine
import framebuffer

pub fn zorro_arch_initialize() {
	framebuffer.initialize()
}