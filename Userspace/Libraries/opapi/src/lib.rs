#![allow(non_snake_case,unused_must_use,non_upper_case_globals,non_camel_case_types)]
#![no_std]
#![feature(lang_items,int_roundings)]

use core::panic::PanicInfo;

extern crate alloc;

pub mod syscall;
pub mod allocator;

#[cfg(target_arch="x86_64")]
#[path = "arch/AMD64.rs"]
pub mod arch;

////////////////////////////////////////////////
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    syscall::exit(255);
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}
////////////////////////////////////////////////
pub struct Stat {
    pub inode_id: i64,
    pub mode: i32,
    pub nlinks: i32,
    pub uid: u32,
    pub gid: u32,
    pub rdev: u64,
    pub size: i64,
    pub blksize: i64,
    pub blocks: i64,

    pub atime: i64,
    pub mtime: i64,
    pub ctime: i64,
}
////////////////////////////////////////////////