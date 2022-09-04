#![no_std]
#![no_main]

#[prelude_import]
mod prelude;

pub mod interfaces;

#[no_mangle]
extern "C" fn main() {
    
}

#[no_mangle]
extern "C" fn eh_personality() {}