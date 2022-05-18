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

use core::panic::PanicInfo;
use core::alloc::Layout;
use crate::arch::CurrentHart;
use log::info;

#[macro_export]
macro_rules! print_startup_message {
    () => {
        crate::Console::Initalize();
        info!("Raven Kernel has awoken...");
        info!("Long live the Raven!");
        info!("Copyright (C) 2020-2022 TalonTheRaven");
    }
}

fn main() -> ! {
    FS::Initalize();
    Drivers::Initalize();
    info!("Starting Init");
    Scheduler::Scheduler::Start(CurrentHart())
}

pub fn InitThread() -> ! {
    loop {
        halt!();
    }
}

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    halt_other_harts!();
    let msg = info.message();
    match msg {
        Some(m) => {
            print!("\x1b[31mpanic (hart 0x{}): Fatal Exception\n", CurrentHart());
            print!("{}\n", m);
            print!("{}\n\x1b[0m", info.location().unwrap());
        }
        None => {
            print!("\x1b[31mpanic (hart 0x{}): Unknown Exception\n", CurrentHart());
            print!("{}\n\x1b[0m", info.location().unwrap());
        }
    }
    halt!();
    loop {}
}

#[lang = "oom"]
fn oom(_: Layout) -> ! {
    panic!("Kernel Heap expansion cannot be satisfied: Out of Memory.");
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}