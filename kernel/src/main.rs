#![no_std]
#![no_main]

//extern crate alloc;
pub mod memory;

#[no_mangle]
extern "C" fn main() {
    // We must first call the amain function within the arch crate to initalize architecture-specific things, such as paging, starting up harts, etc.
    arch::amain();
    loop {};
}

#[no_mangle]
extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    loop {};
}