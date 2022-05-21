use crate::FS::VFS;
use crate::FS::DevFS;
use alloc::sync::{Weak,Arc};
use spin::{Once,Mutex};
use alloc::collections::{BTreeMap,VecDeque};
use alloc::string::{String,ToString};
use crate::Syscall::Errors;

struct PtsDir(usize);
impl PtsDir {
    fn new() -> Arc<Self> {
        Arc::new(Self(DevFS::ReserveDeviceID()))
    }
}
impl DevFS::Device for PtsDir {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        PTSDIR.get().expect("device not ready").clone()
    }
}
impl VFS::Inode for PtsDir {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            inode_id: i64::MAX,
            mode: 0o0040555, // dr-xr-xr-x
            nlinks: 1,
            uid: 0,
            gid: 0,
            rdev: 0,
            size: 0,
            blksize: 0,
            blocks: 0,

            atime: 0,
            mtime: 0,
            ctime: 0,
        })
    }

    fn GetName(&self) -> Result<&str, i64> {
        Ok("pts")
    }
    fn GetParent(&self) -> Option<Arc<dyn VFS::Inode>> {
        Some(VFS::FindMount("/dev").ok().unwrap().1.GetRootInode())
    }

    fn Lookup(&self, name: &str) -> Result<Arc<dyn VFS::Inode>, i64> {
        let lock = PTYS.lock();
        for i in lock.iter() {
            if i.1.client.GetName()? == name {
                return Ok(i.1.client.clone())
            }
        }
        drop(lock);
        Err(0)
    }

    fn ReadDir(&self, index: usize) -> Result<Option<Arc<dyn VFS::Inode>>, i64> {
        let lock = PTYS.lock();
        if index < lock.len() {
            drop(lock);
            return Ok(Some(PTYS.lock().get(&index).unwrap().client.clone()))
        }
        drop(lock);
        Ok(None)
    }

    fn Open(&self, _mode: usize) -> Result<(), i64> {
        Ok(())
    }

    fn Close(&self) {}
}

pub struct PTY {
    pub index: usize,
    pub index_str: String,
    pub client: Arc<dyn VFS::Inode>,
    pub server: Arc<dyn VFS::Inode>,

    // Client read, Server write
    pub pty_read: Mutex<VecDeque<u8>>,
    // Client write, Server read
    pub pty_write: Mutex<VecDeque<u8>>,
}
pub struct PTClient {
    p: Weak<PTY>,
}
impl VFS::Inode for PTClient {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            inode_id: i64::MAX,
            mode: 0o0020666, // crw-rw-rw-
            nlinks: 1,
            uid: 0,
            gid: 0,
            rdev: 0,
            size: 0,
            blksize: 0,
            blocks: 0,

            atime: 0,
            mtime: 0,
            ctime: 0,
        })
    }
    fn GetName(&self) -> Result<&str, i64> {
        return match self.p.upgrade() {
            Some(arc) => {
                let str_size = arc.index_str.len();
                let ptr = arc.index_str.as_str().as_ptr();
                let slice = unsafe {alloc::slice::from_raw_parts(ptr,str_size)};
                Ok(alloc::str::from_utf8(slice).ok().unwrap())
            }
            _ => {
                Err(Errors::ENOENT as i64)
            }
        }
    }
    fn Read(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        match self.p.upgrade() {
            Some(arc) => {
                let mut i = 0;
                let mut lock = arc.pty_read.lock();
                while i < buffer.len() && lock.len() > 0 {
                    buffer[i] = lock.pop_front().unwrap();
                    i += 1;
                }
                drop(lock);
                return i as i64;
            }
            _ => {
                return 0;
            }
        }
    }
    fn Write(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        match self.p.upgrade() {
            Some(arc) => {
                let mut i = 0;
                let mut lock = arc.pty_write.lock();
                while i < buffer.len() {
                    lock.push_back(buffer[i]);
                    i += 1;
                }
                drop(lock);
                return i as i64;
            }
            _ => {
                return 0;
            }
        }
    }
}
pub struct PTServer {
    p: Weak<PTY>,
}
impl VFS::Inode for PTServer {
    fn Read(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        match self.p.upgrade() {
            Some(arc) => {
                let mut i = 0;
                let mut lock = arc.pty_write.lock();
                while i < buffer.len() && lock.len() > 0 {
                    buffer[i] = lock.pop_front().unwrap();
                    i += 1;
                }
                drop(lock);
                return i as i64;
            }
            _ => {
                return 0;
            }
        }
    }
    fn Write(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        match self.p.upgrade() {
            Some(arc) => {
                let mut i = 0;
                let mut lock = arc.pty_read.lock();
                while i < buffer.len() {
                    lock.push_back(buffer[i]);
                    i += 1;
                }
                drop(lock);
                return i as i64;
            }
            _ => {
                return 0;
            }
        }
    }
    fn Close(&self) {

    }
}

static PTSDIR: Once<Arc<PtsDir>> = Once::new();
static PTYS: Mutex<BTreeMap<usize, Arc<PTY>>> = Mutex::new(BTreeMap::new());

pub fn Initalize() {
    DevFS::InstallDevice(PTSDIR.call_once(|| PtsDir::new()).clone());
}