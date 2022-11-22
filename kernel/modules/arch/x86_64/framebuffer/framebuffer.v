module framebuffer

import arch.interfaces.framebuffer as fb_interface
import arch.x86_64.limine

[cinit]
__global (
	volatile fb_request = limine.LimineFramebufferRequest{response: 0}
)

__global (
	fb = &limine.LimineFramebuffer(0)
)

pub struct Framebuffer {}

pub fn (x Framebuffer) get_resolution() fb_interface.ZorroFramebufferResolution {
	return fb_interface.ZorroFramebufferResolution{
		w: int(fb.width)
		h: int(fb.height)
	}
}

pub fn (x Framebuffer) get_depth() u8 {
	return u8(fb.bpp)
}

pub fn (z Framebuffer) get(x int, y int) u32 {
	pos := y*int(fb.width)+x
	ptr := &u32(fb.address)
	if u64(fb.address)+u64(pos) < u64(fb.address) {
		return u32(0)
	} else {
		return unsafe {ptr[pos]}
	}
}

pub fn (x Framebuffer) get_unsafe_pointer() &u8 {
	return &u8(fb.address)
}

pub fn (z Framebuffer) set(x int, y int, color u32) {
	pos := y*int(fb.width)+x
	mut ptr := &u32(fb.address)
	if u64(fb.address)+u64(pos) >= u64(fb.address) {
		unsafe {ptr[pos] = color}
	}
}

pub fn initialize() fb_interface.IZorroFramebuffer {
	fb = unsafe { fb_request.response.framebuffers[0] }
	return Framebuffer{}
}