#![no_std]
#![no_main]

//extern crate alloc;

#[no_mangle]
extern "C" fn main() {

}

#[no_mangle]
extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    loop {};
}