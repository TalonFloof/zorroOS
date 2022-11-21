module framebuffer

pub struct ZorroFramebufferResolution {
pub:
	w int
	h int
}

pub interface IZorroFramebuffer {
	get_resolution() ZorroFramebufferResolution
	get_depth() u8
	get_unsafe_pointer() &u8
	set(int,int,u32)
	get(int,int) u32
	rect(int,int,int,int,u32)
}