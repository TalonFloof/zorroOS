module x86_64

import framebuffer
import ksync
import arch
import panic

pub fn (a &Arch) initialize_early() {
	framebuffer.initialize()
}

pub fn (a &Arch) initialize() {

}