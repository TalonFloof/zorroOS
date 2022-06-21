#![allow(non_snake_case,unused_must_use,non_upper_case_globals,non_camel_case_types)]
#![no_std]
#![feature(lang_items)]

use core::panic::PanicInfo;

#[cfg(target_arch="x86_64")]
#[path = "arch/AMD64.rs"]
pub mod arch;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {};
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}