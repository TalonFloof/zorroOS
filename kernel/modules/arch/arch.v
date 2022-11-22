module arch

import interfaces.framebuffer
import interfaces.logger

[no_init]
pub interface IZorroArch {
	get_framebuffer() ?&framebuffer.IZorroFramebuffer
	get_logger() ?&logger.IZorroLogger
	halt()
}