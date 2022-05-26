use crate::Color::Color;
use crate::Bitmap::Bitmap;

// The bitmap font used originated from qword-os on GitHub. The repo for qword-os can be found here: https://github.com/qword-os/qword.
const BitmapFont: &[u8; 4096] = include_bytes!("BitmapFont");

pub fn Rectangle(bitmap: &mut Bitmap, x: isize, y: isize, w: isize, h: isize, color: Color) {
    for i in y..y+h {
        for j in x..x+w {
            bitmap.SetPixel(j,i,color);
        }
    }
}

pub fn BitmapGlyph(bitmap: &mut Bitmap, c: u8, x: isize, y: isize, scale: isize, color: Color) {
    for i in 0..16 {
        let row = BitmapFont[(c as usize*16)+i];
        for j in 0..8 {
            if (row & (1 << j)) != 0 {
                Rectangle(bitmap,x+((7-j)*scale),y+(i as isize*scale),scale,scale,color);
            }
        }
    }
}

pub fn BitmapString(bitmap: &mut Bitmap, s: &str, x: isize, y: isize, scale: isize, color: Color) {
    let mut index = 0;
    for b in s.bytes() {
        BitmapGlyph(bitmap,b,x + (index * (8*scale)), y, scale, color);
        index += 1;
    }
}

pub fn BitmapStringCenter(bitmap: &mut Bitmap, s: &str, x: isize, y: isize, scale: isize, color: Color) {
    let final_x = x - ((s.len() as isize * (8*scale)) / 2);
    let mut index = 0;
    for b in s.bytes() {
        BitmapGlyph(bitmap,b,final_x + (index * (8*scale)), y-4, scale, color);
        index += 1;
    }
}

pub fn BitmapRenderMonochrome(bitmap: &mut Bitmap, ptr: &[u8], x: isize, y: isize, w: isize, scale: isize, color: Color) {
    let mut index_x = x;
    let mut index_y = y;
    let mut i = 0;
    while i < ptr.len() {
        let val = ptr[i];
        for j in 0..8 {
            if val & (1 << (7-j)) != 0 {
                Rectangle(bitmap,index_x,index_y,scale,scale,color);
            }
            index_x += scale;
            if index_x >= x+(w*scale) {
                index_x = x;
                index_y += scale;
                if !(w as usize).is_power_of_two() {
                    i += 1;
                }
                break;
            }
        }
        i += 1;
    }
}