module x86_64

import interfaces.framebuffer as i_framebuf
import interfaces.logger as i_log
import framebuffer as framebuf
import logger as log
import interfaces.paging as i_paging

[noinit]
pub struct Arch {}

pub fn (arch &Arch) get_framebuffer() ?&i_framebuf.IZorroFramebuffer {
	if usize(limine_fb) == 0 {
		return none
	}
	return &framebuf.zorro_fb
}

pub fn (arch &Arch) get_logger() ?&i_log.IZorroLogger {
	if usize(terminal_request.response) == 0 {
		return none
	}
	return &log.zorro_logger
}

pub fn (arch &Arch) create_vm_space() ?&i_paging.VMSpace {
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

[cinit]
__global (
	zorro_arch = Arch{}
)