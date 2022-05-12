use crate::Arch::Syscall;
use crate::SyscallResult;

pub const RK_IRQ: u64 = u64::from_le_bytes(*(b"rk::irq\0"));
pub const RK_DMA: u64 = u64::from_le_bytes(*(b"rk::dma\0"));
pub const RK_PIO: u64 = u64::from_le_bytes(*(b"rk::pio\0"));
pub const RK_LOG: u64 = u64::from_le_bytes(*(b"rk::log\0"));
pub const RK_TASK: u64 = u64::from_le_bytes(*(b"rk::task"));

pub fn Yield() {
    Syscall(0x00,0,0,0);
}

pub fn GetTID() -> u32 {
    Syscall(0x01,0,0,0).1 as u32
}

pub fn New(parent: Option<u32>) -> Result<u32,SyscallResult> {
    let result = Syscall(0x04,if parent.is_some() {parent.unwrap() as usize} else {0xFFFF_FFFFusize},0,0);
    if matches!(result.0,SyscallResult::Success) {
        return Ok(result.1 as u32);
    }
    return Err(result.0);
}

pub fn Start(task: u32, IP: usize, SP: usize) -> SyscallResult {
    let result = Syscall(0x05,task as usize,IP,SP);
    return result.0;
}

pub fn SendSignal(task: u32, sigtype: u32) -> SyscallResult {
    let result = Syscall(0x06,task as usize,sigtype as usize,0);
    return result.0;
}

pub fn AddPrivilege(task: u32, pri: u64) -> SyscallResult {
    let result = Syscall(0x07,task as usize,(pri & (u32::MAX as u64)) as usize,((pri >> 32) & (u32::MAX as u64)) as usize);
    return result.0;
}

pub fn HasPrivilege(task: u32, pri: u64) -> Result<bool,SyscallResult> {
    let result = Syscall(0x08,task as usize,(pri & (u32::MAX as u64)) as usize,((pri >> 32) & (u32::MAX as u64)) as usize);
    if matches!(result.0,SyscallResult::Success) || matches!(result.0,SyscallResult::Failed) {
        return Ok(matches!(result.0,SyscallResult::Success));
    }
    return Err(result.0);
}

pub fn RemovePrivilege(task: u32, pri: u64) -> SyscallResult {
    let result = Syscall(0x09,task as usize,(pri & (u32::MAX as u64)) as usize,((pri >> 32) & (u32::MAX as u64)) as usize);
    return result.0;
}

pub fn ShareTask(task: u32, other: u32) -> SyscallResult {
    let result = Syscall(0x0a,task as usize,other as usize,0);
    return result.0;
}

pub fn Deref(task: u32) -> SyscallResult {
    let result = Syscall(0x0f,task as usize,0,0);
    return result.0;
}