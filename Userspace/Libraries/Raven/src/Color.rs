#[repr(packed)]
#[derive(Copy,Clone)]
pub struct Color {
    pub blue: u8,
    pub green: u8,
    pub red: u8,
    pub alpha: u8,
}

impl Color {
    pub const fn new_rgb(r: u8, g: u8, b: u8) -> Self {
        Self {
            red: r,
            green: g,
            blue: b,
            alpha: 255,
        }
    }
    pub const fn new_rgba(r: u8, g: u8, b: u8, a: u8) -> Self {
        Self {
            red: r,
            green: g,
            blue: b,
            alpha: a,
        }
    }
    pub const fn new_hex(hex: u32) -> Self {
        Self {
            red: ((hex >> 16) & 0xF8) as u8,
            green: ((hex >> 8) & 0xF8) as u8,
            blue: (hex & 0xF8) as u8,
            alpha: 255,
        }
    }
    pub const fn new_hexa(hex: u32) -> Self {
        Self {
            red: ((hex >> 16) & 0xF8) as u8,
            green: ((hex >> 8) & 0xF8) as u8,
            blue: (hex & 0xF8) as u8,
            alpha: ((hex >> 24) & 0xFF) as u8,
        }
    }

    pub fn to_hexa(&self) -> u32 {
        return unsafe {*(((self as *const Color) as usize) as *const u32)}
    }
}