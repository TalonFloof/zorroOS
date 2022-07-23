use spin::Mutex;
use crate::syscall;

static WRITER: Mutex<Writer> = Mutex::new(Writer);

use crate::file::File;

struct Writer;

impl core::fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        syscall::write(1,s.as_bytes());
        Ok(())
    }
}

#[doc(hidden)]
pub fn _print(args: core::fmt::Arguments) {
    use core::fmt::Write;
    WRITER.lock().write_fmt(args).unwrap();
}

pub fn stdin() -> File {
    File::OpenInternal(0)
}

pub fn stdout() -> File {
    File::OpenInternal(1)
}

pub fn stderr() -> File {
    File::OpenInternal(2)
}