use crate::Arch::Syscall;
use crate::SyscallResult;

pub fn Allocate(task: u32,vaddr: usize,size: usize,writable: bool,executable: bool) -> SyscallResult {
    let sizeflag = size.trailing_zeros() << 4;
    let flag: usize = sizeflag as usize | 0b0100 | (if executable {0b10} else {0}) | (if writable {1} else {0});
    let result = Syscall(0x2,task as usize,vaddr | flag,0);
    return result.0;
}

pub fn MMap(task: u32,vaddr:usize,paddr:usize,size:usize,writable: bool,executable: bool) -> SyscallResult {
    let sizeflag = size.trailing_zeros() << 4;
    let flag: usize = sizeflag as usize | 0b0000 | (if executable {0b10} else {0}) | (if writable {1} else {0});
    let result = Syscall(0x2,task as usize,vaddr | flag,paddr);
    return result.0;
}

pub fn AllocateDMA(task: u32,vaddr:usize,size:usize,writable: bool,executable: bool) -> Result<usize,SyscallResult> {
    let sizeflag = size.trailing_zeros() << 4;
    let flag: usize = sizeflag as usize | 0b1000 | (if executable {0b10} else {0}) | (if writable {1} else {0});
    let result = Syscall(0x2,task as usize,vaddr | flag,0);
    if !matches!(result.0,SyscallResult::Success) {
        return Err(result.0);
    }
    return Ok(result.3);
}

pub fn UMap(task: u32,vaddr:usize,size:usize) -> SyscallResult {
    let sizeflag = (size.trailing_zeros() << 4) as usize;
    let result = Syscall(0x3,task as usize,vaddr | sizeflag,0);
    return result.0;
}
