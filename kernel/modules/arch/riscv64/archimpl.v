module riscv64

import interfaces.framebuffer as i_framebuf
import interfaces.logger as i_log
import interfaces.paging as i_paging

[noinit]
pub struct Arch {}

pub fn (arch &Arch) get_framebuffer() ?&i_framebuf.IZorroFramebuffer {
	return none
}

pub fn (arch &Arch) get_logger() ?&i_log.IZorroLogger {
	return none
}

pub fn (arch &Arch) create_vm_space() ?&i_paging.VMSpace {
	return none
}

[noreturn]
pub fn (arch &Arch) halt() {
	for {}
}

[cinit]
__global (
	zorro_arch = Arch{}
)