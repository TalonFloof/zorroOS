#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use opapi::file::*;
use alloc::vec::Vec;
use alloc::vec;

#[no_mangle]
fn main() {
    opapi::syscall::setpgid(opapi::syscall::getpid(),opapi::syscall::getpid());
    loop {
        println!("owlOS Nightly /dev/pts/0");
        loop {
            print!("owlOS login: ");
            let username = opapi::io::stdin().ReadLine().expect("Something went wrong!");
            print!("Password: ");
            let password = opapi::io::stdin().ReadLine().expect("Something went wrong!");
            if username == "root" { // This is temporary
                break;
            }
            opapi::syscall::nanosleep(3,0);
            println!("\nIncorrect login");
        }
        if let Ok(motd) = File::Open("/etc/motd",O_RDONLY | O_CLOEXEC) {
            if let Ok(msg) = motd.ReadToString() {
                println!("{}", msg);
            }
        }
        let mut status: usize = 0;
        opapi::syscall::forkat(RunShell as usize);
        opapi::syscall::wait(&mut status);
        println!("exit {}", status as isize);
    }
}

fn RunShell() {
    let result = opapi::process::exec("/bin/osh");
    panic!("Failed to load shell: {}", result);
}