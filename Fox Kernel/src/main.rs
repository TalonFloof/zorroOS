#![no_std]
#![no_main]
#![feature(asm_sym,const_btree_new,naked_functions,map_first_last,
const_mut_refs,panic_info_message,lang_items,rustc_private,int_roundings,abi_x86_interrupt)]
#![allow(non_snake_case,unused_must_use,non_upper_case_globals,non_camel_case_types)]

extern crate alloc;

#[cfg(target_arch="x86_64")]
#[path = "AMD64/mod.rs"]
#[macro_use]
pub mod arch;

#[macro_use]
pub mod Console;

pub mod PageFrame;
pub mod Allocator;
pub mod Memory;
pub mod Process;
pub mod Scheduler;
pub mod Framebuffer;
pub mod Syscall;
pub mod FS;
pub mod Drivers;
pub mod CommandLine;
pub mod ELF;

use core::panic::PanicInfo;
use core::alloc::Layout;
use crate::arch::CurrentHart;
use alloc::vec::Vec;
use alloc::string::String;

#[macro_export]
macro_rules! print_startup_message {
    () => {
        crate::Console::Initalize();
        log::info!("Fox Kernel has awoken...");
        log::info!("Copyright (C) 2020-2022 Talon396");
    }
}

pub static mut UNIX_EPOCH: u64 = 0;

fn main(ramdisks: Vec<(String,&[u8])>) -> ! {
    FS::InitalizeEarly();
    Drivers::Initalize();
    FS::Initalize(ramdisks);
    {
        let used = PageFrame::UsedMem.load(core::sync::atomic::Ordering::SeqCst);
	    let total = PageFrame::TotalMem.load(core::sync::atomic::Ordering::SeqCst);
	    log::info!("{} MiB Used out of {} MiB Total", used/1024/1024, total/1024/1024);
    }
    if crate::CommandLine::FLAGS.get().unwrap().contains("--break") {panic!("Break");}
    Scheduler::Scheduler::Start(CurrentHart())
}

pub fn IdleThread() -> ! {
    loop {
        halt!();
    }
}

static mut PANICKING: bool = false;

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    unsafe {crate::Console::QUIET = false;}
    if unsafe{PANICKING} {
        print!("\n\x1b[31m!!!Nested Panic!!!\n");
        halt!();
        loop {};
    }
    unsafe {PANICKING = true;}
    halt_other_harts!();
    let msg = info.message();
    match msg {
        Some(m) => {
            print!("\x1b[31mpanic (hart 0x{}): Fatal Exception\n", CurrentHart());
            print!("{:?}\n", m);
            print!("{}\n\x1b[0m", info.location().unwrap());
        }
        _ => {
            print!("\x1b[31mpanic (hart 0x{}): Unknown Exception\n", CurrentHart());
            print!("{}\n\x1b[0m", info.location().unwrap());
        }
    }
    halt!();
    loop {}
}

#[lang = "oom"]
fn oom(l: Layout) -> ! {
    panic!("Kernel Heap expansion cannot be satisfied: Out of Memory.\nAttempted Allocation Size: 0x{:016x}", l.size());
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {
    panic!("Poisoned function \"eh_personality\" was unexpectedly called");
}