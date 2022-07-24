#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use opapi::file::*;

#[no_mangle]
fn main() {
    // This is temporary
    loop {
        print!("owlOS Nightly /dev/pts/0\nowlOS login: ");
        let username = opapi::io::stdin().ReadLine().expect("Something went wrong!");
        print!("Password: ");
        let password = opapi::io::stdin().ReadLine().expect("Something went wrong!");
        if username == "root" {
            break;
        }
        opapi::syscall::nanosleep(3,0);
        println!("\nIncorrect login");
    }
    if let Ok(motd) = File::Open("/etc/motd",O_RDONLY | O_CLOEXEC) {
        if let Ok(msg) = motd.ReadToString() {
            print!("{}", msg);
        }
    }
    loop {opapi::syscall::sched_yield();}
}