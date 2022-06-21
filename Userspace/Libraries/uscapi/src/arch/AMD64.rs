use core::arch::asm;

pub fn Syscall(index: usize, sc1: usize, sc2: usize, sc3: usize) -> isize {
    unsafe {
        let mut out: usize;
        asm!(
        "push rcx",
        "push r11",
        "syscall",
        "pop r11",
        "pop rcx",
        inout("rax")index => out,
        in("rdi")sc1,
        in("rsi")sc2,
        in("rdx")sc3);
        return out as isize;
    }
}