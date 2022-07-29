#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use alloc::vec::Vec;
use alloc::string::String;
use spin::Mutex;

static CMD: Mutex<Vec<String>> = Mutex::new(Vec::new());

#[no_mangle]
fn main() -> u8 {
    loop {
        print!("[\x1b[1;34mosh\x1b[0m]% ");
        let line: String = opapi::io::stdin().ReadLine().expect("");
        let cmd: Vec<&str> = line.split(" ").collect();
        let mut lock = CMD.lock();
        lock.clear();
        for i in cmd.iter() {
            lock.push(String::from(*i));
        }
        drop(lock);
        if cmd[0] == "cd" {
            opapi::syscall::chdir(cmd[1..].join(" ").as_str());
        } else if cmd[0] == "exit" {
            if cmd.len() == 2 {
                return cmd[1].parse().expect("");
            } else {
                return 0;
            }
        } else if cmd[0] == "pwd" {
            println!("{}", opapi::syscall::getcwd().ok().unwrap());
        } else {
            let mut num = 0;
            opapi::syscall::waitpid(opapi::syscall::forkat(RunProgram as usize),&mut num,0);
        }
    };
}

fn RunProgram() {
    let cmd = CMD.lock().clone();
    if cmd[0].as_bytes()[0] == '/' as u8 || cmd[0].as_bytes()[0] == '.' as u8 {
        opapi::process::exec(cmd[0].as_str());
    } else {
        opapi::process::exec(["/bin/",cmd[0].as_str()].concat().as_str());
    }
    println!("{}: command not found", cmd[0]);
    opapi::syscall::exit(255);
}