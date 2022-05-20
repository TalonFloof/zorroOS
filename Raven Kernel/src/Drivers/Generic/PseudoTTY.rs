use crate::FS::VFS;
use crate::FS::DevFS;
use alloc::sync::Arc;
use spin::{Once,Mutex};
use alloc::collections::BTreeMap;

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
        let lock = PTS.lock();
        for i in lock.iter() {
            if i.1.GetName()? == name {
                return Ok(i.1.clone())
            }
        }
        drop(lock);
        Err(0)
    }

    fn ReadDir(&self, index: usize) -> Result<Option<Arc<dyn VFS::Inode>>, i64> {
        let lock = PTS.lock();
        if index < lock.len() {
            drop(lock);
            return Ok(Some(PTS.lock().get(&index).unwrap().clone()))
        }
        drop(lock);
        Ok(None)
    }

    fn Open(&self, _mode: usize) -> Result<(), i64> {
        Ok(())
    }

    fn Close(&self) {}
}

pub struct TTY {

}

impl VFS::Inode for TTY {

}

static PTSDIR: Once<Arc<PtsDir>> = Once::new();
static PTS: Mutex<BTreeMap<usize, Arc<TTY>>> = Mutex::new(BTreeMap::new());

pub fn Initalize() {
    DevFS::InstallDevice(PTSDIR.call_once(|| PtsDir::new()).clone());
}