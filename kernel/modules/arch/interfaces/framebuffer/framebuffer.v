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
mut:
	get_unsafe_pointer() &u8
	set(int,int,u32)
}

pub fn (mut fb IZorroFramebuffer) rect(x int, y int, w int, h int, color u32) {
	for i in y .. (y+h) {
		for j in x .. (x+h) {
			fb.set(i,j,color)
		}
	}
}