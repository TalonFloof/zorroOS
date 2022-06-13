use crate::FS::VFS::Inode;
use crate::FS::VFS;
use alloc::vec::Vec;
use alloc::string::String;
use spin::Mutex;
use alloc::sync::{Arc,Weak};
use lazy_static::lazy_static;
use crate::Syscall::Errors;
use core::sync::atomic::{Ordering,AtomicI32,AtomicU32,AtomicI64};

pub struct RAMInode {
    id: i64,
    name: String,
    inode: Weak<dyn VFS::Inode>,
    parent: Option<Arc<dyn VFS::Inode>>,
    parent_cast: Option<Arc<RAMInode>>,
    children: Mutex<Vec<Arc<dyn VFS::Inode>>>,
    content: Mutex<Vec<u8>>,
    pub ctime: AtomicI64,
    pub mtime: AtomicI64,
    pub uid: AtomicU32,
    pub gid: AtomicU32,
    pub mode: AtomicI32,
}

impl RAMInode {
    pub fn new(id: i64, name: String, mode: i32, parent: Option<Arc<dyn VFS::Inode>>) -> Arc<Self> {
        let ts = crate::arch::Timer::GetTimeStamp().0;
        Arc::<Self>::new_cyclic(|inode| Self {
            id,
            name,
            parent_cast: if parent.is_none() {None} else {unsafe {Some(Arc::from_raw(Arc::into_raw(parent.as_ref().unwrap().clone()) as *const RAMInode))}},
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

impl VFS::Inode for RAMInode {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        let length = self.content.lock().len() as i64;
        Ok(VFS::Metadata {
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
        let _num = Errors::ENOENT as i64;
        if matches!(self.Lookup(name),Err(_num)) {
            let mut children = self.children.lock();
            let inode = RAMInode::new(NEXT_INODEID.fetch_add(1,Ordering::SeqCst),String::from(name),mode,Some(self.inode.upgrade().unwrap()));
            children.push(inode.clone());
            drop(children);
            return Ok(inode);
        }
        Err(Errors::EEXIST as i64)
    }

    fn Unlink(&self) -> i64 {
        if self.mode.load(Ordering::SeqCst) & 0o0770000 == 0o0040000 {
            if self.children.lock().len() > 0 {
                return Errors::ENOTEMPTY as i64;
            }
        }
        self.parent_cast.as_ref().unwrap().children.lock().retain(|entry| entry.Stat().ok().unwrap().inode_id != self.id);
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

    fn ChOwn(&self, uid: u32, gid: u32) -> i64 {
        self.uid.store(uid,Ordering::SeqCst);
        self.gid.store(gid,Ordering::SeqCst);
        0
    }

    fn ChMod(&self, mode: i32) -> i64 {
        self.mode.store((self.mode.load(Ordering::SeqCst) & !0o777) | (mode & 0o777),Ordering::SeqCst);
        0
    }
}

pub struct InitrdFS;

impl VFS::Filesystem for InitrdFS {
    fn GetRootInode(&self) -> Arc<dyn VFS::Inode> {
        ROOT_INODE.clone()
    }
    fn UMount(&self) -> i64 {
        0
    }
}

static NEXT_INODEID: AtomicI64 = AtomicI64::new(2);
lazy_static! {
    static ref ROOT_INODE: Arc<RAMInode> = RAMInode::new(1,String::from(""),0o0040755,None);
}

// Only use this if the bootloader provided a Ramdisk / Ramdisks.
pub fn Initalize(ramdisks: Vec<(String,&[u8])>) {
    lazy_static::initialize(&ROOT_INODE);
    for (name,data) in ramdisks.iter() {
        if !name.starts_with("Mod") {
            for entry in cpio_reader::iter_files(data) {
                log::debug!("{}", if entry.name().ends_with("...") {entry.name().strip_suffix("...").unwrap()} else {entry.name()});
                let path: Vec<_> = entry.name().split("/").filter(|e| *e != "" && *e != ".").collect();
                let mut cwd: Arc<dyn Inode> = ROOT_INODE.clone();
                for (i, name) in path.iter().enumerate() {
                    if i == path.len() - 1 {
                        if name != &"..." {
                            let mut mode = entry.mode();
                            mode.remove(cpio_reader::Mode::REGULAR_FILE);
                            let inode = cwd.Creat(name,mode.bits() as i32).ok().unwrap();
                            inode.Write(0,entry.file());
                        }
                    } else {
                        match cwd.Lookup(name) {
                            Ok(val) => {
                                cwd = val;
                            }
                            Err(e) => {
                                if e == Errors::ENOENT as i64 {
                                    cwd = cwd.Creat(name,0o0040755).ok().unwrap();
                                } else {
                                    log::error!("Error code #{} while trying to create file \"{}\"", e, entry.name());
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            log::debug!("Freeing {} Pages from old RamDisk", data.len().div_ceil(0x1000));
            crate::PageFrame::Free(data.as_ptr() as *mut u8, (data.len().div_ceil(0x1000) * 0x1000) as u64);
        }
    }
    VFS::Mount("/",Arc::new(InitrdFS));
}
