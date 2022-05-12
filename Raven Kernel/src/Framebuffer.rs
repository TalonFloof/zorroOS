use spin::mutex::Mutex;

const RavenScript: [u16; 95] = [
0x0000,0x2092,0x002d,0x5f7d,0x279e,0x52a5,0x7ad6,0x0012,
0x4494,0x1491,0x0aba,0x05d0,0x1400,0x01c0,0x0400,0x12a4,
0x2b6a,0x749a,0x752a,0x38a3,0x4f4a,0x38cf,0x3bce,0x12a7,
0x3aae,0x49ae,0x0410,0x1410,0x4454,0x0e38,0x1511,0x10e3,
0x73ee,0x5f7a,0x3beb,0x624e,0x3b6b,0x73cf,0x13cf,0x6b4e,
0x5bed,0x7497,0x2b27,0x5add,0x7249,0x5b7d,0x5b6b,0x3b6e,
0x12eb,0x4f6b,0x5aeb,0x388e,0x2497,0x6b6d,0x256d,0x5f6d,
0x5aad,0x24ad,0x72a7,0x6496,0x4889,0x3493,0x002a,0xf000,
0x0011,0x6b98,0x3b79,0x7270,0x7b74,0x6750,0x95d6,0xb9ee,
0x5b59,0x6410,0xb482,0x56e8,0x6492,0x5be8,0x5b58,0x3b70,
0x976a,0xcd6a,0x1370,0x38f0,0x64ba,0x3b68,0x2568,0x5f68,
0x54a8,0xb9ad,0x73b8,0x64d6,0x2492,0x3593,0x03e0,
];

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
    pub fn DrawSymbol(&mut self, x: usize, y: usize, sym: u8, color: u32) {
        let index: usize = (sym - b' ') as usize;
        for i in 0..5 { // y
            for j in 0..3 { // x
                if (RavenScript[index] >> (i*3+j)) & 1 == 1 {
                    self.DrawRect(x+j*3,y+i*3,3,3,color);
                }
            }
        }
    }
    pub fn DrawString(&mut self, x: usize, y: usize, s: &str, color: u32) {
        let mut index = 0;
        let mut yindex = 0;
        for b in s.bytes() {
            if x+(index*12)+12 >= self.width || b == b'\n'{
                index = 0;
                yindex += 3*6;
            }
            if b >= 32 {
                self.DrawSymbol(x + (index * 12), y + yindex, b, color);
                index += 1;
            }
        }
    }
}

pub fn Init(pointer: *mut u32, width: usize, height: usize, stride: usize, bpp: usize) {
    let mut lock = MainFramebuffer.lock();
    *lock = Some(Framebuffer::new(pointer,width,height,stride,bpp));
    /*if bpp == 32 {
        (*lock).as_mut().unwrap().Clear(0xE0E0E0);
    }*/
    drop(lock);
}