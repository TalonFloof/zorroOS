use crate::FS::VFS;
use alloc::vec::Vec;
use alloc::string::String;
use spin::Mutex;
use core::sync::atomic::{Ordering,AtomicI32,AtomicU32,AtomicI64};
use crate::Syscall::Errors;
use alloc::sync::{Arc,Weak};

static NEXT_INODEID: AtomicI64 = AtomicI64::new(2);

pub struct TMPInode {
    id: i64,
    name: String,
    inode: Weak<dyn VFS::Inode>,
    parent: Option<Arc<dyn VFS::Inode>>,
    children: Mutex<Vec<Arc<dyn VFS::Inode>>>,
    content: Mutex<Vec<u8>>,
    pub ctime: AtomicI64,
    pub mtime: AtomicI64,
    pub uid: AtomicU32,
    pub gid: AtomicU32,
    pub mode: AtomicI32,
}

impl TMPInode {
    pub fn new(id: i64, name: String, mode: i32, parent: Option<Arc<dyn VFS::Inode>>) -> Arc<Self> {
        let ts = crate::arch::Timer::GetTimeStamp().0;
        Arc::<Self>::new_cyclic(|inode| Self {
            id,
            name,
            parent,
            inode: inode.clone(),
            children: Mutex::new(Vec::new()),
            content: Mutex::new(Vec::new()),
            ctime: AtomicI64::new(ts),
            mtime: AtomicI64::new(ts),
            uid: AtomicU32::new(0),
            gid: AtomicU32::new(0),
            mode: AtomicI32::new(mode),
        })
    }
}

impl VFS::Inode for TMPInode {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        let length = self.content.lock().len() as i64;
        Ok(VFS::Metadata {
            device_id: 0,
            inode_id: self.id,
            mode: self.mode.load(Ordering::SeqCst),
            nlinks: 1,
            uid: self.uid.load(Ordering::SeqCst),
            gid: self.gid.load(Ordering::SeqCst),
            rdev: 0,
            size: length,
            blksize: 0,
            blocks: 0,

            atime: self.mtime.load(Ordering::SeqCst),
            mtime: self.mtime.load(Ordering::SeqCst),
            ctime: self.ctime.load(Ordering::SeqCst),
            reserved1: 0,
            reserved2: 0,
            reserved3: 0,
        })
    }

    fn GetName(&self) -> Result<&str, i64> {
        Ok(self.name.as_str())
    }

    fn GetParent(&self) -> Option<Arc<dyn VFS::Inode>> {
        self.parent.clone()
    }

    fn Read(&self, offset: i64, buffer: &mut [u8]) -> i64 {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 != 0o0040000 {
            let lock = self.content.lock();
            for (i, b) in (&lock.as_slice()[offset as usize..offset as usize + buffer.len()]).iter().enumerate() {
                buffer[i] = *b;
            }
            drop(lock);
            return buffer.len() as i64;
        }
        -(Errors::EISDIR as i64)
    }

    fn Write(&self, offset: i64, buffer: &[u8]) -> i64 {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 != 0o0040000 {
            let mut lock = self.content.lock();
            if (lock.len() as i64) < offset + buffer.len() as i64 {
                lock.resize(offset as usize + buffer.len(),0);
            }
            lock.as_mut_slice()[offset as usize..offset as usize+buffer.len()].copy_from_slice(buffer);
            drop(lock);
            return buffer.len() as i64;
        }
        -(Errors::EINVAL as i64) // This should never happen, but just in case...
    }

    fn Truncate(&self, size: usize) -> i64 {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 != 0o0040000 {
            let mut lock = self.content.lock();
            if lock.len() < size {
                return -(Errors::EINVAL as i64);
            }
            lock.truncate(size);
            drop(lock);
            return 0;
        }
        -(Errors::EISDIR as i64)
    }

    fn Creat(&self, name: &str, mode: i32) -> Result<Arc<dyn VFS::Inode>, i64> {
        const _num: i64 = Errors::ENOENT as i64;
        if matches!(self.Lookup(name),Err(_num)) {
            let mut children = self.children.lock();
            let inode = TMPInode::new(NEXT_INODEID.fetch_add(1,Ordering::SeqCst),String::from(name),mode,Some(self.inode.upgrade().unwrap()));
            children.push(inode.clone());
            drop(children);
            return Ok(inode);
        }
        Err(Errors::EEXIST as i64)
    }

    fn Unlink(&self, name: &str) -> i64 {
        let file = self.Lookup(name);
        if file.is_err() {
            return -file.err().unwrap();
        }
        let id = file.as_ref().ok().unwrap().Stat().ok().unwrap().inode_id;
        if file.as_ref().ok().unwrap().Stat().ok().unwrap().mode & 0o0770000 == 0o0040000 {
            if self.children.lock().len() > 0 {
                return Errors::ENOTEMPTY as i64;
            }
        }
        self.children.lock().retain(|entry| entry.Stat().ok().unwrap().inode_id != id);
        return 0;
    }

    fn Lookup(&self, name: &str) -> Result<Arc<dyn VFS::Inode>, i64> {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 == 0o0040000 {
            let children = self.children.lock();
            for i in children.iter() {
                if i.GetName()? == name {
                    return Ok(i.clone())
                }
            }
            drop(children);
            return Err(Errors::ENOENT as i64)
        }
        Err(Errors::ENOTDIR as i64)
    }

    fn ReadDir(&self, index: usize) -> Result<Option<Arc<dyn VFS::Inode>>, i64> {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 == 0o0040000 {
            if index < self.children.lock().len() {
                return Ok(Some(self.children.lock().get(index).unwrap().clone()))
            }
            return Ok(None)
        }
        Err(Errors::ENOTDIR as i64)
    }

    fn Open(&self, _mode: usize) -> Result<(), i64> {
        Ok(())
    }

    fn Close(&self) {}

    fn ChOwn(&self, uid: i32, gid: i32) -> i64 {
        if uid != -1 {self.uid.store(uid as u32,Ordering::SeqCst);}
        if gid != -1 {self.gid.store(gid as u32,Ordering::SeqCst);}
        0
    }

    fn ChMod(&self, mode: i32) -> i64 {
        self.mode.store((self.mode.load(Ordering::SeqCst) & !0o777) | (mode & 0o777),Ordering::SeqCst);
        0
    }
}