use crate::FS::VFS;
use alloc::sync::Arc;
use alloc::vec::Vec;
use alloc::string::String;
use spin::Mutex;
use crate::Syscall::Errors;
use lazy_static::lazy_static;

pub struct RootInode {
    children: Mutex<Vec<Arc<VRootInode>>>,
}

impl VFS::Inode for RootInode {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Stat()
        }
        Ok(VFS::Metadata {
            inode_id: 0,
            mode: 0o0040755, // drwxr-xr-x
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
        Ok("")
    }

    fn Read(&self, offset: i64, buffer: &mut [u8]) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Read(offset,buffer)
        }
        -(Errors::ENOSYS as i64)
    }

    fn Write(&self, offset: i64, buffer: &mut [u8]) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Write(offset,buffer)
        }
        -(Errors::ENOSYS as i64)
    }

    fn Truncate(&self, size: usize) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Truncate(size)
        }
        -(Errors::ENOSYS as i64)
    }

    fn Creat(&self, name: &str, mode: u64) -> Result<Arc<dyn VFS::Inode>, i64> {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Creat(name,mode)
        }
        if mode & 0o0040000 == 0o0040000 {
            let mut lock = self.children.lock();
            let len = lock.len();
            lock.push(Arc::new(VRootInode {
                id: (len+1) as i64,
                name: String::from(name),
                parent: ROOTFS.root.clone(),
            }));
            drop(lock);
            return Ok(self.children.lock().get(len).unwrap().clone())
        }
        Err(Errors::ENOSYS as i64)
    }

    fn Unlink(&self, name: &str) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Unlink(name)
        }
        Errors::ENOSYS as i64
    }

    fn Lookup(&self, name: &str) -> Result<Arc<dyn VFS::Inode>, i64> {
        let lock = self.children.lock();
        for i in lock.iter() {
            if i.GetName()? == name {
                return Ok(i.clone())
            }
        }
        drop(lock);
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().Lookup(name);
        }
        Err(Errors::ENOSYS as i64)
    }

    fn ReadDir(&self, index: usize) -> Result<Option<Arc<dyn VFS::Inode>>, i64> {
        let lock = self.children.lock();
        if index < lock.len() {
            drop(lock);
            return Ok(Some(self.children.lock().get(index).unwrap().clone()))
        }
        if let Some(fs) = &ROOTFS.true_fs {
            let result = fs.GetRootInode().ReadDir(index-lock.len());
            drop(lock);
            return result;
        }
        drop(lock);
        Ok(None)
    }

    fn IOCtl(&self, cmd: usize, arg: usize) -> Result<usize, i64> {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().IOCtl(cmd,arg)
        }
        Err(Errors::ENOSYS as i64)
    }

    fn Open(&self, _mode: usize) -> Result<(), i64> {
        Ok(())
    }

    fn Close(&self) {}

    fn ChOwn(&self, uid: u32, gid: u32) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().ChOwn(uid,gid)
        }
        Errors::ENOSYS as i64
    }

    fn ChMod(&self, mode: i32) -> i64 {
        if let Some(fs) = &ROOTFS.true_fs {
            return fs.GetRootInode().ChMod(mode)
        }
        Errors::ENOSYS as i64
    }
}

pub struct VRootInode {
    id: i64,
    name: String,
    parent: Arc<dyn VFS::Inode>
}

impl VFS::Inode for VRootInode {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            inode_id: self.id,
            mode: 0o0040755, // drwxr-xr-x
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
        Ok(self.name.as_str())
    }
    fn GetParent(&self) -> Option<Arc<dyn VFS::Inode>> {
        Some(self.parent.clone())
    }
}

pub struct RootFS {
    root: Arc<dyn VFS::Inode>,
    true_fs: Option<Arc<dyn VFS::Filesystem>>,
}

impl VFS::Filesystem for RootFS {
    fn GetRootInode(&self) -> Arc<dyn VFS::Inode> {
        self.root.clone()
    }
    fn UMount(&self) -> i64 {
        0
    }
}

lazy_static! {
    static ref ROOTFS: RootFS = RootFS {
        root: Arc::new(RootInode {
            children: Mutex::new(Vec::new())
        }),
        true_fs: None,
    };
}

pub fn Initalize() {
    let ptr = (&ROOTFS as *const _) as usize;
    VFS::Mount("/",unsafe {Arc::from_raw(ptr as *const RootFS)});
    ROOTFS.root.Creat("dev",0o0040000);
    ROOTFS.root.Creat("proc",0o0040000);
}