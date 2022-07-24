#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use opapi::file::*;

#[no_mangle]
fn main() {
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
    loop {opapi::syscall::sched_yield();}
}