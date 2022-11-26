module arch

import interfaces.framebuffer
import interfaces.logger
import interfaces.paging
import api

[no_init]
pub interface IZorroArch {
	initialize_early()
	initialize()
	get_framebuffer() ?&framebuffer.IZorroFramebuffer
	get_logger() ?&logger.IZorroLogger
	create_vm_space() ?&paging.VMSpace
	halt()
}