#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

pub mod Console;

use core::sync::atomic::Ordering;
use opapi::file::*;

#[no_mangle]
fn main() {
    if !Console::SetupConsole() {
        panic!("Failed too early!");
    }
    print!("\x1b[1;30;40m##\x1b[31;41m##\x1b[32;42m##\x1b[33;43m##\x1b[34;44m##\x1b[35;45m##\x1b[36;46m##\x1b[37;47m##\x1b[0m");
    println!(" Welcome to owlOS!");
    // Legal stuff
    println!("Copyright (C) 2020-2022 Talon396\n");
    println!("Licensed under the Apache License, Version 2.0 (the \"License\").");
    println!("You may obtain a copy of the License at\n");
    println!("    http://www.apache.org/licenses/LICENSE-2.0\n");
    println!("Unless required by applicable law or agreed to in writing, software");
    println!("distributed under the License is distributed on an \"AS IS\" BASIS,");
    println!("WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.");
    println!("See the License for the specific language governing permissions and");
    println!("limitations under the License.\n");
    if opapi::syscall::fork() != 0 {
        Console::Loop();
    } else {
        print!("Press CTRL+ALT+DEL to startup UNIX Sessions. ");
        while !Console::SESSION_STARTED.load(Ordering::Relaxed) {core::hint::spin_loop();}
        print!("\x1b[30m\x1b[42mAuthorized\x1b[0m\n\n");
        opapi::syscall::close(0);
        opapi::syscall::close(1);
        opapi::syscall::close(2);
        let pts = opapi::syscall::open("/dev/pts/0",O_RDWR);
        if pts < 0 {
            panic!("Failed to open Pseudo-Teletype #0, Reason: {}", pts);
        }
        if opapi::syscall::dup2(pts,1).is_negative() || opapi::syscall::dup2(pts,2).is_negative() {
            panic!("Failed to open Pseudo-Teletype #0, Reason: dup2 failed");
        }
        let result = opapi::syscall::exec("/bin/login");
        if result < 0 {
            panic!("Failed to start /bin/login, Reason: {}", result);
        }
        panic!("You shouldn't be seeing this");
    }
}