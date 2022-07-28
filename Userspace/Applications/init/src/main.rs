#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

pub mod Console;

use core::sync::atomic::Ordering;
use opapi::file::*;
use alloc::vec;
use alloc::vec::Vec;

#[no_mangle]
fn main() {
    if opapi::syscall::fork() != 0 {
        if !Console::SetupConsole() {
            panic!("Failed too early!");
        }
        Console::Loop();
    } else {
        while !Console::PTY_READY.load(Ordering::Relaxed) {core::hint::spin_loop();}
        let pts = opapi::syscall::open("/dev/pts/0",O_RDWR);
        if pts < 0 {
            panic!("Failed to open Pseudo-Teletype #0, Reason: {}", pts);
        }
        if opapi::syscall::dup2(pts,1).is_negative() || opapi::syscall::dup2(pts,2).is_negative() {
            panic!("Failed to open Pseudo-Teletype #0, Reason: dup2 failed");
        }
        print!("\x1b[?25lPress CTRL+ALT+DEL to startup UNIX Sessions.....[ ]\x08\x08");
        let mut counter = 0;
        while !Console::SESSION_STARTED.load(Ordering::Relaxed) {
            print!("{}\x08", if counter == 0 {"/"} else if counter == 1 {"-"} else if counter == 2 {"\\"} else {"|"});
            opapi::syscall::nanosleep(0,150*1000000);
            counter = (counter + 1) % 4;
        }
        drop(opapi::io::stdout().Write(b"\x1b[?25h\x1b[1m\x1b[32m\xfb\x1b[0m]\n\n"));
        let result = opapi::process::exec("/bin/login");
        if result != 0 {
            panic!("Failed to start /bin/login, Reason: {}", result);
        }
        panic!("You shouldn't be seeing this");
    }
}