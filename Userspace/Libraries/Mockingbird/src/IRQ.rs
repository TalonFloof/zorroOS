use crate::Arch::Syscall;
use crate::SyscallResult;

pub fn Bind(irq: usize) -> bool {
    let result = Syscall(0x20,irq,0,0);
    return matches!(result.0,SyscallResult::Success);
}

pub fn Unbind(irq: usize) -> bool {
    let result = Syscall(0x3f,irq,0,0);
    return matches!(result.0,SyscallResult::Success);
}