use core::arch::asm;
use x86_64::{PrivilegeLevel, VirtAddr};
use x86_64::registers::model_specific::*;
use x86_64::registers::rflags::RFlags;
use x86_64::registers::segmentation::SegmentSelector;
use crate::arch::Task::State;

#[naked]
#[no_mangle]
#[doc(hidden)]
unsafe extern "C" fn __syscall() {
    asm!(
    "swapgs",
    "mov gs:[0x8], rsp",
    "mov rsp, gs:[0x0]",
    "cld",
    "push qword ptr 0x1b",
    "push qword ptr gs:[0x8]",
    "push r11",
    "push qword ptr 0x18",
    "push rcx",
    "",
    "push rax",
    "push rbx",
    "push rcx",
    "push rdx",
    "push rsi",
    "push rdi",
    "push rbp",
    "push r8",
    "push r9",
    "push r10",
    "push r11",
    "push r12",
    "push r13",
    "push r14",
    "push r15",
    "",
    "mov rdi, rsp",
    "mov rbp, 0",
    "swapgs",
    "call x86SCall",
    "swapgs",
    "pop r15",
    "pop r14",
    "pop r13",
    "pop r12",
    "pop r11",
    "pop r10",
    "pop r9",
    "pop r8",
    "pop rbp",
    "pop rdi",
    "pop rsi",
    "pop rdx",
    "pop rcx",
    "pop rbx",
    "pop rax",
    "",
    "mov rsp, gs:[0x8]",
    "swapgs",
    "sysretq",
    options(noreturn)
    );
}

#[no_mangle]
extern "C" fn x86SCall(
    cr: &mut State
) {
    crate::Syscall::SystemCall(cr);
}

pub fn Initialize() {
    unsafe {
        Efer::write(Efer::read() | EferFlags::NO_EXECUTE_ENABLE | EferFlags::SYSTEM_CALL_EXTENSIONS);
        Star::write(SegmentSelector::new(8,PrivilegeLevel::Ring3),SegmentSelector::new(7,PrivilegeLevel::Ring3),SegmentSelector::new(5,PrivilegeLevel::Ring0),SegmentSelector::new(6,PrivilegeLevel::Ring0)).unwrap();
        LStar::write(VirtAddr::new(__syscall as u64));
        SFMask::write(RFlags::from_bits_truncate(0xfffffffe));
    }
}