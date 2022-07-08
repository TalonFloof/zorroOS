#![no_std]
#![no_main]
#![allow(non_snake_case)]

#[macro_use]
extern crate opapi;
extern crate alloc;

pub mod Console;

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
    loop {opapi::syscall::fork();}
}