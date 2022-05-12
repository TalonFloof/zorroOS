use core::arch::asm;
use crate::SyscallResult;

pub const DMA_BEGIN: usize = 0x7F_0000_0000;

pub fn Syscall(index: usize, sc1: usize, sc2: usize, sc3: usize) -> (SyscallResult,usize,usize,usize) {
    unsafe {
        let mut out1: usize;
        let mut out2: usize;
        let mut out3: usize;
        let mut out4: usize;
        asm!(
        "push rcx",
        "push r11",
        "syscall",
        "pop r11",
        "pop rcx",
        inout("rax")index => out1,
        inout("rdi")sc1 => out2,
        inout("rsi")sc2 => out3,
        inout("rdx")sc3 => out4);
        return (match out1 {
            00 => SyscallResult::Success,
            01 => SyscallResult::Failed,
            02 => SyscallResult::UnknownSyscall,
            03 => SyscallResult::BadArgument,
            04 => SyscallResult::BadAddress,
            05 => SyscallResult::BadID,
            06 => SyscallResult::PermissionDenied,
            07 => SyscallResult::NotImplemented,
            08 => SyscallResult::IPCFullOrEmpty,
            09 => SyscallResult::IPCNoQueue,
            10 => SyscallResult::IPCExceedsBuffer,
            _ => { unimplemented!(); }
        }, out2,out3,out4);
    }
}

pub fn x64PIO(iotype: usize, val: usize, port: u16) -> Result<usize,SyscallResult> {
    let result = Syscall(0x41,iotype,val,port as usize);
    if matches!(result.0,SyscallResult::Success) {
        return Ok(result.2);
    }
    return Err(result.0);
}