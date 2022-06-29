use spin::mutex::Mutex;
use tinytga::*;

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

const FOXKERNEL_LOGO: &[u8] = include_bytes!("../Logo.tga");
const FOXKERNEL_STAGE1: &[u8] = include_bytes!("../Stage1.tga");
const FOXKERNEL_STAGE2: &[u8] = include_bytes!("../Stage2.tga");
const FOXKERNEL_STAGE3: &[u8] = include_bytes!("../Stage3.tga");
const FOXKERNEL_STAGE4: &[u8] = include_bytes!("../Stage4.tga");

pub fn Init(pointer: *mut u32, width: usize, height: usize, stride: usize, bpp: usize) {
    let mut lock = MainFramebuffer.lock();
    *lock = Some(Framebuffer::new(pointer,width,height,stride,bpp));
    if bpp == 32 {
        (*lock).as_mut().unwrap().Clear(0x000000);
        if unsafe {crate::Console::QUIET} {
            let tga = RawTga::from_slice(FOXKERNEL_LOGO).unwrap();
            for pixel in tga.pixels() {
                (*lock).as_mut().unwrap().DrawPixel((width/2)-(tga.size().width as usize/2)+pixel.position.x as usize-8,(height/2)-(tga.size().height as usize/2)+pixel.position.y as usize,pixel.color);
            }
            (*lock).as_mut().unwrap().DrawString((width/2)-(5*16),(height/2)+(tga.size().height as usize/2),"Fox Kernel",0xFFFFFF,2);
            (*lock).as_mut().unwrap().DrawString(0,0,"In celebration of owlOS's 100th Commit!",0x040404,1);
        }
    }
    drop(lock);
}

pub fn Progress(num: u8) {
    if unsafe {!crate::Console::QUIET} {return;}
    let mut lock = MainFramebuffer.lock();
    let width = (*lock).as_ref().unwrap().width;
    let height = (*lock).as_ref().unwrap().height;
    if (*lock).as_ref().unwrap().bpp == 32 {
        let xpos = ((width/2)-(24*4))+(num as usize * 48)+16;
        let ypos = height/2+64+48;
        if num == 0 {
            let tga = RawTga::from_slice(FOXKERNEL_STAGE1).unwrap();
            for pixel in tga.pixels() {
                (*lock).as_mut().unwrap().DrawPixel(xpos+pixel.position.x as usize-8,ypos+pixel.position.y as usize,pixel.color);
            }
        } else if num == 1 {
            let tga = RawTga::from_slice(FOXKERNEL_STAGE2).unwrap();
            for pixel in tga.pixels() {
                (*lock).as_mut().unwrap().DrawPixel(xpos+pixel.position.x as usize-8,ypos+pixel.position.y as usize,pixel.color);
            }
        } else if num == 2 {
            let tga = RawTga::from_slice(FOXKERNEL_STAGE3).unwrap();
            for pixel in tga.pixels() {
                (*lock).as_mut().unwrap().DrawPixel(xpos+pixel.position.x as usize-8,ypos+pixel.position.y as usize,pixel.color);
            }
        } else if num == 3 {
            let tga = RawTga::from_slice(FOXKERNEL_STAGE4).unwrap();
            for pixel in tga.pixels() {
                (*lock).as_mut().unwrap().DrawPixel(xpos+pixel.position.x as usize-8,ypos+pixel.position.y as usize,pixel.color);
            }
        }
    }
}