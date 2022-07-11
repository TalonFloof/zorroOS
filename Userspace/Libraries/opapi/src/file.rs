use alloc::string::String;
use alloc::vec;
use alloc::vec::Vec;

pub const O_EXEC: usize      = 1;
pub const O_RDONLY: usize    = 2;
pub const O_RDWR: usize      = 3;
pub const O_SEARCH: usize    = 4;
pub const O_WRONLY: usize    = 5;
pub const O_APPEND: usize    = 0x0008;
pub const O_CREAT: usize     = 0x0010;
pub const O_DIRECTORY: usize = 0x0020;
pub const O_EXCL: usize      = 0x0040;
pub const O_NOCTTY: usize    = 0x0080;
pub const O_NOFOLLOW: usize  = 0x0100;
pub const O_TRUNC: usize     = 0x0200;
pub const O_NONBLOCK: usize  = 0x0400;
pub const O_DSYNC: usize     = 0x0800;
pub const O_RSYNC: usize     = 0x1000;
pub const O_SYNC: usize      = 0x2000;
pub const O_CLOEXEC: usize   = 0x4000;
pub const O_PATH: usize      = 0x8000;

pub const SEEK_CUR: usize = 1;
pub const SEEK_END: usize = 2;
pub const SEEK_SET: usize = 3;

pub struct File(isize);

impl File {
    pub fn Open(path: &str, mode: usize) -> Result<Self,isize> {
        let result = crate::syscall::open(path,mode);
        if result >= 0 {
            return Ok(File(result));
        } else {
            return Err(result);
        }
    }
    pub fn Read(&self, buf: &mut [u8]) -> Result<usize,isize> {
        let result = crate::syscall::read(self.0,buf);
        if result < 0 {
            return Err(result);
        }
        Ok(result as usize)
    }
    pub fn ReadToString(&self, s: &mut String) -> Result<(),isize> {
        let curpos = crate::syscall::lseek(self.0,0,SEEK_CUR);
        if curpos < 0 {
            return Err(curpos);
        }
        let size = crate::syscall::lseek(self.0,0,SEEK_END);
        if size < 0 {
            return Err(size);
        }
        {
            let seekresult = crate::syscall::lseek(self.0,curpos,SEEK_SET);
            if seekresult < 0 {
                return Err(seekresult);
            }
        }
        let mut bytes = "\0".repeat((size-curpos) as usize);
        let result = crate::syscall::read(self.0,unsafe {bytes.as_bytes_mut()});
        if result < 0 {
            drop(bytes);
            return Err(result);
        }
        bytes.truncate(result as usize);
        s.push_str(bytes.as_str());
        drop(bytes);
        Ok(())
    }
    pub fn Write(&self, buf: &[u8]) -> Result<usize,isize> {
        let result = crate::syscall::write(self.0,buf);
        if result < 0 {
            return Err(result);
        }
        Ok(result as usize)
    }
    pub fn WriteFromString(&self, s: &str) -> Result<usize,isize> {
        let result = crate::syscall::write(self.0,s.as_bytes());
        if result < 0 {
            return Err(result);
        }
        Ok(result as usize)
    }
    pub fn Seek(&self, offset: isize, whence: usize) -> Result<usize,isize> {
        let result = crate::syscall::lseek(self.0,offset,whence);
        if result < 0 {
            return Err(result);
        }
        Ok(result as usize)
    }
    pub fn ReadDir(&self) -> ReadDir {
        return ReadDir(self.0);
    }
}

pub struct ReadDir(isize);

#[allow(dead_code)]
pub struct DirEntry {
    pub inode_id: i64,
    pub offset: i64,
    pub length: i64,
    pub file_type: i64,
    pub name: String,
}

impl Iterator for ReadDir {
    type Item = DirEntry;
    fn next(&mut self) -> Option<DirEntry> {
        let mut buf = vec![0u8; 288];
        let result = crate::syscall::read(self.0,buf.as_mut_slice());
        if result <= 0 {
            drop(buf);
            return None;
        }
        let ptr = buf.as_ptr() as *const i64;
        let entry = unsafe {DirEntry {
            inode_id: ptr.read(),
            offset: ptr.offset(1).read(),
            length: ptr.offset(2).read(),
            file_type: ptr.offset(3).read(),
            name: String::from(cstr_core::CStr::from_ptr((ptr as *const i8).offset(32)).to_str().ok().unwrap()),
        }};
        drop(ptr);
        drop(buf);
        return Some(entry);
    }
}

impl Drop for File {
    fn drop(&mut self) {
        crate::syscall::close(self.0);
    }
}