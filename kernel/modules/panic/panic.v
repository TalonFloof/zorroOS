module panic

import arch.interfaces.framebuffer
import arch.x86_64.framebuffer as fbimpl

pub enum ZorroPanicCategory {
	imcompatable_hardware
	out_of_memory
	generic
	ramdisk
}

[noreturn]
pub fn panic(category ZorroPanicCategory, msg string) {
	fb := fbimpl.Framebuffer{}
	framebuffer.IZorroFramebuffer(&fb).clear(0xffffff)
	for {
		asm amd64 {
			cli
			hlt
		}
	}
	for {}
}