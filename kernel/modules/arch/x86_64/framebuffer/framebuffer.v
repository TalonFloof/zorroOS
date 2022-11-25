module framebuffer

import arch.interfaces.framebuffer as fb_interface
import arch.x86_64.limine

[cinit]
__global (
	volatile fb_request = limine.LimineFramebufferRequest{response: 0}
	limine_fb = &limine.LimineFramebuffer(0)
)

pub struct Framebuffer {}

pub const (
	zorro_fb = fb_interface.IZorroFramebuffer(Framebuffer{})
)

pub fn (x &Framebuffer) get_resolution() fb_interface.ZorroFramebufferResolution {
	return fb_interface.ZorroFramebufferResolution{
		w: int(limine_fb.width)
		h: int(limine_fb.height)
	}
}

pub fn (x &Framebuffer) get_depth() u8 {
	return u8(limine_fb.bpp)
}

pub fn (z &Framebuffer) get(x int, y int) u32 {
	pos := y*int(limine_fb.width)+x
	ptr := &u32(limine_fb.address)
	if u64(limine_fb.address)+u64(pos) < u64(limine_fb.address) {
		return u32(0)
	} else {
		return unsafe {ptr[pos]}
	}
}

[unsafe]
pub fn (x &Framebuffer) get_unsafe_pointer() &u8 {
	return &u8(limine_fb.address)
}

pub fn (z &Framebuffer) set(x int, y int, color u32) {
	pos := y*int(limine_fb.width)+x
	mut ptr := &u32(limine_fb.address)
	if u64(limine_fb.address)+u64(pos) >= u64(limine_fb.address) {
		unsafe {ptr[pos] = color}
	}
}

pub fn initialize() {
	limine_fb = unsafe { fb_request.response.framebuffers[0] }
}