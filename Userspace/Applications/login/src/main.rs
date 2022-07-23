#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use alloc::vec;

#[no_mangle]
fn main() {
    loop {
        print!("owlOS Late-Alpha /dev/pts/0\nUsername: ");
        let mut buf = vec![0u8; 1];
        loop {
            opapi::syscall::read(0,buf.as_mut_slice());
            opapi::syscall::write(0,buf.as_mut_slice());
            opapi::syscall::sched_yield();
        }
    }
}