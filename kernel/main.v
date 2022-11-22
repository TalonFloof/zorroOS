module main

import arch.interfaces.framebuffer
import arch.x86_64

pub fn main() { // To make the V compiler shut up.
	zorro_kernel_main()
}

pub fn zorro_kernel_main() {
	asm amd64 {
		cli
	}
	x86_64.zorro_arch_initialize()
}