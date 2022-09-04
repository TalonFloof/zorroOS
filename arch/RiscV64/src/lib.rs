#![no_std]
use core::arch::global_asm;

pub mod arch_api;

global_asm!(include_str!("asm/bootstrap.S"));

pub fn amain() {

}