use spin::{RwLock,Mutex};
use crate::Framebuffer::MainFramebuffer;
use alloc::vec::Vec;
use core::marker::PhantomData;
use log::{Record, Metadata};

pub static WRITER: Mutex<Writer> = Mutex::new(Writer {cursor_x:0,cursor_y:0,text_color: 0xFFFFFF});

pub struct Writer {
    pub cursor_x: usize,
    pub cursor_y: usize,
    pub text_color: u32,
}

struct KernelLogger;

impl log::Log for KernelLogger {
    fn enabled(&self, _metadata: &Metadata) -> bool {
        true
    }

    fn log(&self, record: &Record) {
        if MUTE_LOG.reader_count() == 0 {
            crate::print!("[{}] {}\n", record.level(), record.args());
        }
    }

    fn flush(&self) {}
}

static LOGGER: KernelLogger = KernelLogger;
pub static MUTE_LOG: RwLock<PhantomData<()>> = RwLock::new(PhantomData);

impl core::fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        crate::arch::UART::write_serial(s);
        let mut lock = MainFramebuffer.lock();
        if lock.is_some() {
            let fb = lock.as_mut().unwrap();
            let mut ansi_seq: Vec<u8> = Vec::new();
            let mut parse_ansi = false;
            let console_height = fb.height.div_floor(6*3) * (6*3);
            for b in s.bytes() {
                if self.cursor_x*12 > (fb.width/(6*3))*(6*3) || b == b'\n' {
                    self.cursor_x = 0;
                    if self.cursor_y*(6*3) >= console_height-(6*3) {
                        unsafe {core::ptr::copy((fb.pointer+((6*3)*fb.stride as u64)) as *const u32, fb.pointer as *mut u32, (fb.width*console_height)-((6*3)*fb.width));}
                        fb.DrawRect(0, self.cursor_y*(6*3), fb.width, 6*3, 0x2E3436);
                    } else {
                        self.cursor_y += 1;
                    }
                }
                if b >= 32 && b <= 127 {
                    if !parse_ansi {
                        fb.DrawSymbol(self.cursor_x*12, self.cursor_y*(6*3), b, self.text_color);
                        self.cursor_x += 1;
                    } else {
                        if b == b'm' {
                            if ansi_seq.len() == 3 {
                                if ansi_seq[1] == b'3' {
                                    if ansi_seq[2] == b'1' {
                                        self.text_color = 0xCC0000;
                                    } else if ansi_seq[2] == b'5' {
                                        self.text_color = 0x75507B;
                                    } else if ansi_seq[2] == b'7' {
                                        self.text_color = 0xFFFFFF;
                                    }
                                }
                            } else if ansi_seq.len() == 2 {
                                if ansi_seq[1] == b'0' {
                                    self.text_color = 0xFFFFFF;
                                }
                            }
                            parse_ansi = false;
                            ansi_seq.clear();
                        } else {
                            ansi_seq.push(b);
                        }
                    }
                } else if b == 0x1b {
                    parse_ansi = true;
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

pub fn Initalize() {
    log::set_logger(&LOGGER)
        .map(|()| log::set_max_level(log::LevelFilter::Trace));
}