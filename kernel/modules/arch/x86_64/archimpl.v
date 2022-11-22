module x86_64

import interfaces.framebuffer as i_framebuf
import interfaces.logger as i_log
import framebuffer as framebuf
import logger as log

[noinit]
pub struct Arch {}

pub fn (arch &Arch) get_framebuffer() ?&i_framebuf.IZorroFramebuffer {
	if usize(limine_fb) == 0 {
		return none
	}
	return &framebuf.zorro_fb
}

pub fn (arch &Arch) get_logger() ?&i_log.IZorroLogger {
	return none
}

[noreturn]
pub fn (arch &Arch) halt() {
	for {
		asm volatile amd64 {
			cli
			hlt
		}
	}
	for {}
}

__global (
	zorro_arch = Arch{}
)