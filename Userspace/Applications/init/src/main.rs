#![no_std]
#![no_main]
#![allow(non_snake_case)]

#[macro_use]
extern crate opapi;
extern crate alloc;

pub mod Console;

#[no_mangle]
fn main() -> u8 {
    if !Console::SetupConsole() {
        panic!("Failed too early!");
    }
    print!("\x1b[1;30;40m##\x1b[31;41m##\x1b[32;42m##\x1b[33;43m##\x1b[34;44m##\x1b[35;45m##\x1b[36;46m##\x1b[37;47m##\x1b[0m");
    println!(" Welcome to owlOS!");
    println!("(C) 2020-2022 Talon396");
    loop {opapi::syscall::sched_yield();}
    return 0;
}