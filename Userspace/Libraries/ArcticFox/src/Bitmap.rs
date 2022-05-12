use alloc::vec;
use alloc::vec::Vec;
use crate::Color::Color;

pub struct Bitmap {
    pub width: usize,
    pub height: usize,
    pub bitmap: Vec<Color>,
    pub raw_bitmap: &'static mut [Color],
    pub is_direct: bool,
}

impl Bitmap {
    pub fn new(width: usize, height: usize) -> Self {
        let mut out = Self {
            width,
            height,
            bitmap: vec![Color::new_hexa(0); width*height],
            raw_bitmap: unsafe {core::slice::from_raw_parts_mut(0 as *mut Color,1)},
            is_direct: false,
        };
        out.raw_bitmap = unsafe {&mut *(out.bitmap.as_mut_slice() as *mut [Color])};
        return out;
    }
    pub fn SetPixel(&mut self, x: isize, y: isize, clr: Color) {
        if x >= 0 && x < self.width as isize && y >= 0 && y < self.height as isize {
            self.raw_bitmap[((y*self.width as isize)+x) as usize] = clr;
        }
    }
    pub fn Clear(&mut self, clr: Color) {
        for i in 0..self.raw_bitmap.len() {
            self.raw_bitmap[i] = clr;
        }
    }
}

