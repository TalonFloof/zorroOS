#![allow(non_snake_case,unused_must_use,non_upper_case_globals,non_camel_case_types)]
#![no_std]
#![feature(lang_items,panic_info_message,int_roundings,const_mut_refs)]

use core::panic::PanicInfo;
use spin::Mutex;

#[cfg(target_arch="x86_64")]
#[path = "AMD64.rs"]
pub mod Arch;

pub mod Task;
pub mod IPC;
pub mod IRQ;
pub mod Memory;

#[cfg(feature = "alloc")]
pub mod Heap;

#[cfg(feature = "alloc")]
pub mod Allocator;

#[repr(usize)]
pub enum SyscallResult {
    Success = 0,
    Failed,
    UnknownSyscall,
    BadArgument,
    BadAddress,
    BadID,
    PermissionDenied,
    NotImplemented,
    IPCFullOrEmpty,
    IPCNoQueue,
    IPCExceedsBuffer
}

pub fn Log(msg: &str) {
    Arch::Syscall(0x40,msg.as_ptr() as usize,msg.as_bytes().len(),0);
}

//////////////// DARK MAGIC ////////////////
static WRITER: Mutex<Writer> = Mutex::new(Writer);

#[doc(hidden)]
struct Writer;

impl core::fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        Log(s);
        Ok(())
    }
}

#[doc(hidden)]
pub fn _log(args: core::fmt::Arguments) {
    use core::fmt::Write;
    WRITER.lock().write_fmt(args).unwrap();
}

////////////////////////////////////////////

pub fn Now() -> usize {
    return Arch::Syscall(0x42,0,0,0).1;
}

pub fn Sleep(alarm: usize) {
    let deadline = Now() + alarm;
    while Now() < deadline {
        Task::Yield();
    }
}

#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => ($crate::_log(format_args!($($arg)*)));
}

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    log!("\x1b[31mTask #{}, {}, {}\n\x1b[0m", Task::GetTID(), info.message().unwrap(), info.location().unwrap());
    Task::SendSignal(Task::GetTID(),u32::MAX);
    loop {
        Task::Yield();
    };
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}