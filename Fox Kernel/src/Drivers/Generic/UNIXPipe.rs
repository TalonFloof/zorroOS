use crate::FS::VFS;
use alloc::collections::VecDeque;
use spin::Mutex;
use core::sync::atomic::{AtomicUsize,Ordering};
use crate::Syscall::Errors;
use alloc::sync::Arc;

pub struct Pipe {
    buffer: Mutex<VecDeque<u8>>,
    refs: AtomicUsize,
}

impl VFS::Inode for Pipe {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            device_id: 0,
            inode_id: i64::MAX,
            mode: 0o0000666, // -rw-rw-rw-
            nlinks: 1,
            uid: 0,
            gid: 0,
            rdev: 0,
            size: 0,
            blksize: 0,
            blocks: 0,

            atime: unsafe {crate::UNIX_EPOCH as i64},
            mtime: unsafe {crate::UNIX_EPOCH as i64},
            ctime: unsafe {crate::UNIX_EPOCH as i64},
            reserved1: 0,
            reserved2: 0,
            reserved3: 0,
        })
    }
    fn GetName(&self) -> Result<&str, i64> {
        Ok("[fox kernel anonymous unix pipe]")
    }
    fn Read(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        if self.refs.load(Ordering::SeqCst) <= 1 {
            return -Errors::EPIPE as i64;
        }
        let mut buf = self.buffer.lock();
        if buf.len() == 0 {
            drop(buf);
            return -Errors::EAGAIN as i64;
        }
        let length = if buf.len() < buffer.len() {buf.len()} else {buffer.len()};
        for i in 0..length {
            buffer[i] = buf.pop_front().unwrap();
        }
        drop(buf);
        return length as i64;
    }
    fn Write(&self, _offset: i64, buffer: &[u8]) -> i64 {
        if self.refs.load(Ordering::SeqCst) <= 1 {
            return -Errors::EPIPE as i64;
        }
        let mut buf = self.buffer.lock();
        if buf.len() >= 4096 {
            drop(buf);
            return -Errors::EAGAIN as i64;
        }
        let length = if buf.len()+buffer.len() > 4096 {buf.len()} else {buffer.len()};
        for i in 0..length {
            buf.push_back(buffer[i]);
        }
        drop(buf);
        return length as i64;
    }
    fn Open(&self, _mode: usize) -> Result<(), i64> {
        self.refs.fetch_add(1,Ordering::SeqCst);
        Ok(())
    }
    fn Close(&self) {
        self.refs.fetch_sub(1,Ordering::SeqCst);
    }
}

impl Pipe {
    pub fn new() -> (Arc<dyn VFS::Inode>, Arc<dyn VFS::Inode>) {
        let pipe = Arc::new(Pipe {
            buffer: Mutex::new(VecDeque::new()),
            refs: AtomicUsize::new(2),
        });
        (pipe.clone(), pipe)
    }
}