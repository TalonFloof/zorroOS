use crate::arch::Syscall;
use cstr_core::{CStr,CString};
use crate::Stat;

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
    Syscall(0x05,fd as usize,buf.as_mut_ptr() as usize,buf.len())
}

pub fn write(fd: isize, buf: &[u8]) -> isize {
    Syscall(0x06,fd as usize,buf.as_ptr() as usize,buf.len())
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

pub fn chown(path: &str, uid: i32, gid: i32,) -> isize {
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

pub fn execv(path: &str, argv: &[&CStr]) -> isize {
    let cpath = CString::new(path).expect("owlOS Programmer API: String conversion failed");
    let ptr = cpath.into_raw();
    let ret = Syscall(0x12,ptr as usize,argv.as_ptr() as usize,0);
    let _ = unsafe {CString::from_raw(ptr)}; // This prevents memory leaking from occuring.
    ret
}

pub fn waitpid() {

}

pub fn sbrk(expand: isize) -> isize {
    Syscall(0x22,expand as usize,0,0)
}

pub fn foxkernel_powerctl(cmd: usize) -> isize {
    Syscall(0xf0,cmd,0,0)
}