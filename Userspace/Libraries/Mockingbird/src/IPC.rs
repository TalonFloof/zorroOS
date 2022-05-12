use crate::Arch::Syscall;
use crate::SyscallResult;

pub fn SendAsync(task: u32, msg: &[u8]) -> SyscallResult {
    let result = Syscall(0x0b,task as usize,msg.as_ptr() as usize,msg.len());
    return result.0;
}

pub fn RecvAsync(task: u32, msgptr: &mut [u8]) -> Result<u32,SyscallResult> {
    let result = Syscall(0x0c,task as usize,msgptr.as_mut_ptr() as usize,msgptr.len());
    if !matches!(result.0,SyscallResult::Success) {
        return Err(result.0);
    }
    return Ok(result.1 as u32);
}

pub fn AccessCTL(task: u32, access: bool) -> SyscallResult {
    let result = Syscall(0x0d,task as usize,if access {1} else {0},0);
    return result.0;
}

pub fn SendSync(task: u32, msg: &[u8], alarm: usize) -> SyscallResult {
    let deadline = if alarm == usize::MAX {alarm} else {Syscall(0x42,0,0,0).1 + alarm};
    while Syscall(0x42,0,0,0).1 < deadline {
        let result = SendAsync(task,msg);
        if matches!(result,SyscallResult::Success) || (!matches!(result,SyscallResult::Success) && !matches!(result,SyscallResult::IPCFullOrEmpty) && !matches!(result,SyscallResult::IPCNoQueue)) {
            return result;
        }
        crate::Task::Yield();
    }
    return SyscallResult::NotImplemented; // Indecates Timeout
}

pub fn RecvSync(task: u32, msgptr: &mut [u8], alarm: usize) -> Result<u32,SyscallResult> {
    let deadline = if alarm == usize::MAX {alarm} else {crate::Now() + alarm};
    while crate::Now() < deadline {
        let result = RecvAsync(task,msgptr);
        if result.is_ok() {
            return result;
        }
        let status = result.err().unwrap();
        if !matches!(status,SyscallResult::IPCFullOrEmpty) && !matches!(status,SyscallResult::IPCNoQueue) {
            return Err(status);
        }
        crate::Task::Yield();
    }
    return Err(SyscallResult::NotImplemented); // Indecates Timeout
}