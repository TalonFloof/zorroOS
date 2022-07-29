#![no_std]
#![no_main]
#![allow(non_snake_case,non_camel_case_types)]

#[macro_use]
extern crate opapi;
extern crate alloc;

use opapi::file::*;

#[no_mangle]
fn main() {
    let cwd = opapi::syscall::getcwd().ok().unwrap();
    let file = File::Open(cwd.as_str(),O_DIRECTORY).expect("Unknown Directory");
    for i in file.ReadDir() {
        let mut info = opapi::Stat {
            device_id: 0,
            inode_id: 0,
            mode: 0,
            nlinks: 0,
            uid: 0,
            gid: 0,
            rdev: 0,
            size: 0,
            atime: 0,
            reserved1: 0,
            mtime: 0,
            reserved2: 0,
            ctime: 0,
            reserved3: 0,
            blksize: 0,
            blocks: 0,
        };
        let path = if cwd.len() == 1 {["/",i.name.as_str()].concat()} else {[cwd.as_str(),i.name.as_str()].join("/")};
        if opapi::syscall::stat(path.as_str(),&mut info) == 0 {
            let mode = info.mode;
            let file_type = (mode & 0x7000) >> 12;
            println!("{}{}{}{}{}{}{}{}{}{} {:4} {:4} {:8} {}", if file_type == 2 {"c"} else if file_type == 4 {"d"} else {"-"},if mode&0x100!=0{"r"}else{"-"},if mode&0x80!=0{"w"}else{"-"},if mode&0x40!=0{"x"}else{"-"}, if mode&0x20!=0{"r"}else{"-"},if mode&0x10!=0{"w"}else{"-"},if mode&0x8!=0{"x"}else{"-"}, if mode&0x4!=0{"r"}else{"-"},if mode&0x2!=0{"w"}else{"-"},if mode&0x1!=0{"x"}else{"-"}, info.uid, info.gid, info.size, i.name);
        }
    }
}