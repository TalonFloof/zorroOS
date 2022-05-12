use x86_64::instructions::port::*;

#[macro_export]
macro_rules! write_byte {
    ($num:expr) => {{
        use x86_64::instructions::port::*;
        unsafe {
            while (u8::read_from_port(0x3F8+5) & 0x20) == 0 {core::hint::spin_loop()}
            u8::write_to_port(0x3F8,$num);
        }
    }};
}

#[inline(always)]
pub fn write_serial(s: &str) {
    for b in s.bytes() {
        unsafe {
            while (u8::read_from_port(0x3F8+5) & 0x20) == 0 {core::hint::spin_loop()}
            u8::write_to_port(0x3F8,b);
        }
    }
}

pub fn Setup() {
    unsafe {
        u8::write_to_port(0x3f8+1,0x00);    // Disable all interrupts
        u8::write_to_port(0x3f8+3,0x80);    // Enable DLAB (set baud rate divisor)
        u8::write_to_port(0x3f8+0,0x01);    // Set divisor to 1 (lo byte) 115200 baud
        u8::write_to_port(0x3f8+1,0x00);    //                  (hi byte)
        u8::write_to_port(0x3f8+3,0x03);    // 8 bits, no parity, one stop bit
        u8::write_to_port(0x3f8+2,0xC7);    // Enable FIFO, clear them, with 14-byte threshold
        u8::write_to_port(0x3f8+4,0x03);
    }
}