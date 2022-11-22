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

pub fn (fb IZorroFramebuffer) render_monochrome_bitmap(x int, y int, w int, h int, scale int, color u32, line_size u64, ptr &u8) {
	for i in 0 .. h {
		for j in 0 .. w {
			byte_offset := (u64(i)*line_size)+(u64(j)/8)
			bit_offset := u64(j) % 8
			dat := unsafe {ptr[byte_offset]}
			if dat & (1 << (7-bit_offset)) != 0 {
				fb.rect(x+(j*scale),y+(i*scale),scale,scale,color)
			}
		}
	}
}