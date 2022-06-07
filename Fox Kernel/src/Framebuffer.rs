use spin::mutex::Mutex;

const FoxScript: &[u8; 4096] = include_bytes!("FoxScript");

pub static MainFramebuffer: Mutex<Option<Framebuffer>> = Mutex::new(None);

pub struct Framebuffer {
    pub pointer: u64,
    pub width: usize,
    pub height: usize,
    pub stride: usize,
    pub bpp: usize,
}

impl Framebuffer {
    pub fn new(pointer: *mut u32, width: usize, height: usize, stride: usize, bpp: usize) -> Self {
        Self {
            pointer: pointer as u64,
            width,
            height,
            stride,
            bpp,
        }
    }
    pub fn DrawPixel(&mut self, x: usize, y: usize, color: u32) {
        if x < self.width && y < self.height {
            unsafe { (self.pointer as *mut u32).offset((x + y * self.width) as isize).write_volatile(color); }
        }
    }
    pub fn DrawRect(&mut self, x: usize, y: usize, w: usize, h: usize, color: u32) {
        for i in x..x+w {
            for j in y..y+h {
                self.DrawPixel(i,j,color);
            }
        }
    }
    pub fn Clear(&mut self, color: u32) {
        self.DrawRect(0,0,self.width,self.height,color);
    }
    pub fn DrawSymbol(&mut self, x: usize, y: usize, sym: u8, color: u32, scale: usize) {
        for i in 0..16 { // y
            let row = FoxScript[(sym as usize*16)+i];
            for j in 0..8 { // x
                if (row & (1 << j)) != 0 {
                    self.DrawRect(x+(7-j)*scale,y+i*scale,scale,scale,color);
                }
            }
        }
    }
    pub fn DrawString(&mut self, x: usize, y: usize, s: &str, color: u32, scale: usize) {
        let mut index = 0;
        let mut yindex = 0;
        for b in s.bytes() {
            if x+(index*(8*scale))+(8*scale) >= self.width || b == b'\n' {
                index = 0;
                yindex += scale*16;
            }
            if b >= 32 {
                self.DrawSymbol(x + (index * (8*scale)), y + yindex, b, color, scale);
                index += 1;
            }
        }
    }
}

pub fn Init(pointer: *mut u32, width: usize, height: usize, stride: usize, bpp: usize) {
    let mut lock = MainFramebuffer.lock();
    *lock = Some(Framebuffer::new(pointer,width,height,stride,bpp));
    if bpp == 32 {
        (*lock).as_mut().unwrap().Clear(0x000000);
    }
    drop(lock);
}