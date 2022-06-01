#![allow(non_snake_case,unused_must_use,non_upper_case_globals,non_camel_case_types)]
#![no_std]

extern crate alloc;

pub mod Bitmap;
pub mod Color;
pub mod Painter;

pub struct Framebuffer {
    pub pointer: u64,
    pub width: usize,
    pub height: usize,
    pub stride: usize,
    pub bpp: usize,
    pub buffer: Bitmap::Bitmap,
}

impl Framebuffer {
    pub fn new(pointer: u64, width: usize, height: usize, stride: usize, bpp: usize) -> Self {
        Self {
            pointer: pointer,
            width,
            height,
            stride,
            bpp,
            buffer: Bitmap::Bitmap::new(width,height),
        }
    }
    pub fn new_direct(pointer: u64, width: usize, height: usize, stride: usize, bpp: usize) -> Self {
        if bpp == 32 {
            return Self {
                pointer: pointer,
                width,
                height,
                stride,
                bpp,
                buffer: Bitmap::Bitmap {
                    width: width,
                    height: height,
                    bitmap: alloc::vec::Vec::new(),
                    raw_bitmap: unsafe { core::slice::from_raw_parts_mut(pointer as *mut Color::Color,width*height) },
                    is_direct: true,
                },
            };
        }
        panic!("ArcticFox: Direct Framebuffers must strictly have a depth of 32-bits, we attempted to create one with a {}-bit depth...", bpp);
    }
    pub fn blit(&self) {
        if !self.buffer.is_direct {
            unsafe { core::ptr::copy(self.buffer.raw_bitmap.as_ptr(),self.pointer as *mut Color::Color,self.width*self.height); }
        }
    }
}

