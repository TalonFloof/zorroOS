#![no_std]
#![no_main]

extern crate opapi;
extern crate alloc;

#[no_mangle]
extern "C" fn _start() -> ! {
    if opapi::syscall::fork() != 0 { // Original Thread
        loop {};
    } else { // New Thread
        loop {};
    }
}