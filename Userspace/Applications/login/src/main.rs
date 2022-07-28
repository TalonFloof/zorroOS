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
        let shell_pid = opapi::syscall::fork();
        if shell_pid != 0 {
            let mut status: usize = 0;
            opapi::syscall::waitpid(shell_pid,&mut status,0);
            println!("exit {}", status as isize);
        } else {
            let args: Vec<*const u8> = vec![b"/usr/bin/bash\0".as_ptr(),core::ptr::null()];
            let result = opapi::syscall::execv("/usr/bin/bash",args.as_slice());
            panic!("Failed to load!");
            loop {opapi::syscall::sched_yield();}
        }
    }
}