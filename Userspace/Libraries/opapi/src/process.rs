use cstr_core::CString;
use alloc::vec::Vec;

pub fn exec(path: &str) -> isize {
    let mut arg: Vec<*const u8> = Vec::new();
    arg.push(CString::new(path).expect("Invalid Path Name").as_ptr() as *const u8);
    arg.push(core::ptr::null());
    crate::syscall::execv(path,arg.as_slice())
}

pub fn execv(path: &str, argv: &[&str]) -> isize {
    let mut arg: Vec<*const u8> = Vec::new();
    arg.push(CString::new(path).expect("Invalid Path Name").as_ptr() as *const u8);
    for i in argv.iter() {
        arg.push(CString::new(*i).expect("Invalid Argument").as_ptr() as *const u8);
    }
    arg.push(core::ptr::null());
    crate::syscall::execv(path,arg.as_slice())
}

pub fn execve(path: &str, argv: &[&str], envp: &[&str]) -> isize {
    let mut arg: Vec<*const u8> = Vec::new();
    arg.push(CString::new(path).expect("Invalid Path Name").as_ptr() as *const u8);
    for i in argv.iter() {
        arg.push(CString::new(*i).expect("Invalid Argument").as_ptr() as *const u8);
    }
    arg.push(core::ptr::null());
    let mut env: Vec<*const u8> = Vec::new();
    for i in envp.iter() {
        arg.push(CString::new(*i).expect("Invalid Argument").as_ptr() as *const u8);
    }
    env.push(core::ptr::null());
    crate::syscall::execve(path,arg.as_slice(),env.as_slice())
}