module framebuffer

pub struct ZorroFramebufferResolution {
pub:
	w int
	h int
}

pub interface IZorroFramebuffer {
	get_resolution() ZorroFramebufferResolution
	get_depth() u8
	get(int,int) u32
	get_unsafe_pointer() &u8
	set(int,int,u32)
}

pub fn (fb IZorroFramebuffer) rect(x int, y int, w int, h int, color u32) {
	for i in y .. (y+h) {
		for j in x .. (x+w) {
			fb.set(j,i,color)
		}
	}
}

pub fn (fb IZorroFramebuffer) clear(color u32) {
	resolution := fb.get_resolution()
	fb.rect(0,0,resolution.w,resolution.h,color)
}

