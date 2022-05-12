use spin::Mutex;
use crate::Framebuffer::MainFramebuffer;

pub static WRITER: Mutex<Writer> = Mutex::new(Writer {cursor_x:0,cursor_y:0});

pub struct Writer {
    pub cursor_x: usize,
    pub cursor_y: usize,
}

impl core::fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        crate::arch::UART::write_serial(s);
        let mut lock = MainFramebuffer.lock();
        if lock.is_some() {
            let fb = lock.as_mut().unwrap();
            for b in s.bytes() {
                if self.cursor_x*12 >= fb.width || b == b'\n' {
                    self.cursor_x = 0;
                    self.cursor_y += 1;
                    if self.cursor_y*(6*3) >= fb.height {
                        self.cursor_y = 0;
                    }

                }
                if b >= 32 && b <= 127 {
                    fb.DrawSymbol(self.cursor_x*12, self.cursor_y*(6*3), b, 0xFFFFFF);
                    self.cursor_x += 1;
                }
            }
        }
        drop(lock);
        Ok(())
    }
}

#[doc(hidden)]
pub fn _print(args: core::fmt::Arguments) {
    use core::fmt::Write;
    WRITER.lock().write_fmt(args).unwrap();
}

#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => (crate::Console::_print(format_args!($($arg)*)));
}