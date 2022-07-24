use crate::arch::Syscall;
use cstr_core::{CString};
use crate::Stat;
use alloc::string::String;
use alloc::vec;

pub fn sched_yield() {
    Syscall(0x00,0,0,0);
}

pub(crate) fn exit(status: u8) -> ! {
    Syscall(0x01,status as usize,0,0);
    unreachable!();
}

pub fn fork() -> i32 {
    Syscall(0x02,0,0,0) as i32
}

pub fn open(path: &str, mode: usize) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x03,ptr as usize,mode,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn close(fd: isize) -> isize {
    Syscall(0x04,fd as usize,0,0)
}

pub fn read(fd: isize, buf: &mut [u8]) -> isize {
    loop {
        let status = Syscall(0x05,fd as usize,buf.as_mut_ptr() as usize,buf.len());
        if status != -11 {
            return status;
        }
        Syscall(0,0,0,0); // Yield
    }
}

pub fn write(fd: isize, buf: &[u8]) -> isize {
    loop {
        let status = Syscall(0x06,fd as usize,buf.as_ptr() as usize,buf.len());
        if status != -11 {
            return status;
        }
        Syscall(0,0,0,0); // Yield
    }
}

pub fn lseek(fd: isize, offset: isize, whence: usize) -> isize {
    Syscall(0x07,fd as usize,offset as usize,whence)
}

pub fn dup(fd: isize) -> isize {
    Syscall(0x08,fd as usize,-1isize as usize,0)
}

pub fn dup2(old_fd: isize, new_fd: isize) -> isize {
    Syscall(0x08,old_fd as usize,new_fd as usize,0)
}

pub fn unlink(path: &str) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x0a,ptr as usize,0,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn stat(path: &str, buf: &mut Stat) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x0b,ptr as usize,buf as *mut _ as usize,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn fstat(fd: isize, buf: &mut Stat) -> isize {
    Syscall(0x0c,fd as usize,buf as *mut _ as usize,0)
}

pub fn access(path: &str, mode: usize) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x0d,ptr as usize,mode,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn chmod(path: &str, mode: usize) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x0e,ptr as usize,mode,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn chown(path: &str, uid: i32, gid: i32) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x0f,ptr as usize,uid as usize,gid as usize);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn umask(mode: usize) -> usize {
    Syscall(0x10,mode,0,0) as usize
}

pub fn ioctl(fd: isize, req: usize, arg: usize) -> isize {
    Syscall(0x11,fd as usize,req,arg)
}

pub fn exec(path: &str) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x12,ptr as usize,0,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn execv(path: &str, argv: &[*const u8]) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x12,ptr as usize,argv.as_ptr() as usize,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn execve(path: &str, argv: &[*const u8], envp: &[*const u8]) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let arg2: usize = argv.as_ptr() as usize;
    let arg3: usize = envp.as_ptr() as usize;
    let ret = Syscall(0x12,ptr as usize,arg2,arg3);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn wait(wstatus: *mut usize) -> isize {
    loop {
        let result = Syscall(0x13,-1isize as usize,wstatus as usize,0);
        if result != 0 {
            return result;
        }
        Syscall(0,0,0,0); // Yield
    }
}

pub fn waitpid(pid: i32, wstatus: *mut usize, opt: usize) -> isize {
    loop {
        let result = Syscall(0x13,pid as usize,wstatus as usize,0);
        if result != 0 || opt & 1 == 1 {
            return result;
        }
        Syscall(0,0,0,0); // Yield
    }
}

pub fn getuid() -> u32 {
    Syscall(0x14,0,0,0) as u32
}

pub fn geteuid() -> u32 {
    Syscall(0x15,0,0,0) as u32
}

pub fn getgid() -> u32 {
    Syscall(0x16,0,0,0) as u32
}

pub fn getegid() -> u32 {
    Syscall(0x17,0,0,0) as u32
}

pub fn getpid() -> i32 {
    Syscall(0x1a,0,0,0) as i32
}

pub fn getppid() -> i32 {
    Syscall(0x1b,0,0,0) as i32
}

pub fn setpgid(pid: i32, group: i32) -> isize {
    Syscall(0x1c,pid as usize,group as usize,0)
}

pub fn getpgrp() -> i32 {
    Syscall(0x1d,0,0,0) as i32
}

pub fn signal(sig: u8, handler: &fn(u8)) -> isize {
    Syscall(0x1e,sig as usize,handler as *const _ as usize,0)
}

pub fn kill(pid: i32, sig: u8) -> isize {
    Syscall(0x1f,pid as usize,sig as usize,0)
}

pub fn sigreturn() {
    Syscall(0x20,0,0,0);
}

pub fn nanosleep(secs: i64, nanos: i64) {
    let mut deadline = getclock();
    deadline.0 += secs+((deadline.1+nanos)/1000000000);
    deadline.1 = (deadline.1+nanos)%1000000000;
    loop {
        let cur = getclock();
        if cur.0 > deadline.0 || (cur.0 == deadline.0 && cur.1 >= deadline.1) {
            return;
        }
        sched_yield();
    }
}

pub fn getclock() -> (i64,i64) {
    let mut array = [0i64; 2];
    Syscall(0x21,array.as_mut_ptr() as usize,unsafe {array.as_mut_ptr().offset(1) as usize},0);
    return (array[0],array[1]);
}

pub fn chdir(path: &str) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x22,ptr as usize,0,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn getcwd() -> Result<String,isize> {
    let size = Syscall(0x23,0,usize::MAX,0) as usize;
    let mut path = String::from_utf8(vec![0; size]).ok().unwrap();
    let ret = Syscall(0x23,path.as_mut_ptr() as usize,size,0);
    if ret.is_negative() {
        return Err(ret);
    } else {
        return Ok(path);
    }
}

pub fn pipe() -> Result<(isize,isize),isize> {
    let mut array = [0isize; 2];
    let result = Syscall(0x24,array.as_mut_ptr() as usize,0,0);
    if result == 0 {
        return Ok((array[0],array[1]));
    }
    Err(result)
}

#[repr(C)]
pub(crate) struct MmapStruct {
    addr: usize,
    size: usize,
    prot: usize,
    flags: usize,
    fd: usize,
    offset: isize,
}

pub fn mmap(addr: usize, size: usize, prot: usize, flags: usize, fd: isize, offset: isize) -> isize {
    let args = MmapStruct {
        addr,
        size,
        prot,
        flags,
        fd: fd as usize,
        offset,
    };
    let result = Syscall(0x25,&args as *const _ as usize,0,0);
    drop(args);
    result
}

pub fn foxkernel_powerctl(cmd: usize) -> isize {
    Syscall(0xf0,cmd,0,0)
}