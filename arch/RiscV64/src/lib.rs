#![no_std]
use core::arch::global_asm;

extern crate alloc;

pub mod arch_api;
pub mod sbi;
pub mod log_api;

global_asm!(include_str!("asm/bootstrap.S"));

pub fn amain() {

}