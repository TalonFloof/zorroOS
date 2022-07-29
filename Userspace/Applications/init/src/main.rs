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
use spin::Once;

pub static RUNLEVEL: Once<usize> = Once::new();

#[no_mangle]
fn main() {
    RUNLEVEL.call_once(|| opapi::syscall::foxkernel_powerctl(1468614837) as usize);
    if RUNLEVEL.get().unwrap() == &0 {
        opapi::syscall::foxkernel_powerctl(3166499024);
    } else if RUNLEVEL.get().unwrap() == &1 {
        opapi::syscall::forkat(SingleUserThread as usize);
        if !Console::SetupConsole() {
            panic!("Failed too early!");
        }
        println!("owlOS has been booted into Rescue Mode. If you didn't boot owlOS with run level 1,");
        println!("then the Fox Kernel had a serious issue while booting. Rescue Mode allows you to");
        println!("preform administrative actions to fix owlOS in the event that the machine is broken.");
        println!("If you didn't mean to enter this mode, then reboot this machine and use a run level");
        println!("of 2 or higher to enter multi-user mode.\n");
        println!("Press CTRL+ALT+DEL to enter the shell...\n");
        Console::Loop();
    } else if RUNLEVEL.get().unwrap() >= &2 && RUNLEVEL.get().unwrap() <= &5 {
        opapi::syscall::forkat(LoginThread as usize);
        if !Console::SetupConsole() {
            panic!("Failed too early!");
        }
        Console::Loop();
    }
}

fn SingleUserThread() {
    while !Console::PTY_READY.load(Ordering::Relaxed) {core::hint::spin_loop();}
    let pts = opapi::syscall::open("/dev/pts/0",O_RDWR);
    if pts < 0 {
        panic!("Failed to open Pseudo-Teletype #0, Reason: {}", pts);
    }
    if opapi::syscall::dup2(pts,1).is_negative() || opapi::syscall::dup2(pts,2).is_negative() {
        panic!("Failed to open Pseudo-Teletype #0, Reason: dup2 failed");
    }
    while !Console::SESSION_STARTED.load(Ordering::Relaxed) {opapi::syscall::sched_yield();}
    let result = opapi::process::exec("/bin/osh");
    if result != 0 {
        panic!("Failed to start /bin/osh, Reason: {}", result);
    }
    panic!("You shouldn't be seeing this");
}

fn LoginThread() {
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