use crate::FS::VFS;
use alloc::sync::Arc;
use core::sync::atomic::{AtomicUsize,Ordering};
use spin::Mutex;
use crate::Syscall::Errors;
use alloc::vec::Vec;
use lazy_static::lazy_static;

static DEVICES: Mutex<Vec<Arc<dyn Device>>> = Mutex::new(Vec::new());
static NEXT_DEVICE: AtomicUsize = AtomicUsize::new(0);

pub trait Device: Send + Sync {
    fn DeviceID(&self) -> usize;
    fn Inode(&self) -> Arc<dyn VFS::Inode>;
}

pub struct DevRootInode {}

impl VFS::Inode for DevRootInode {
    fn Lookup(&self, name: &str) -> Result<Arc<dyn VFS::Inode>, i64> {
        let lock = DEVICES.lock();
        for i in lock.iter() {
            if i.Inode().GetName()? == name {
                return Ok(i.Inode())
            }
        }
        drop(lock);
        Err(0)
    }

    fn ReadDir(&self, index: usize) -> Result<Option<Arc<dyn VFS::Inode>>, i64> {
        let lock = DEVICES.lock();
        if index < lock.len() {
            drop(lock);
            return Ok(Some(DEVICES.lock().get(index).unwrap().Inode()))
        }
        drop(lock);
        Ok(None)
    }

    fn Open(&self, _mode: usize) -> Result<(), i64> {
        Ok(())
    }

    fn Close(&self) {}
}

pub struct DevFS {
    root: Arc<dyn VFS::Inode>,
}

impl VFS::Filesystem for DevFS {
    fn GetRootInode(&self) -> Arc<dyn VFS::Inode> {
        self.root.clone()
    }
    fn UMount(&self) -> i64 {
        0
    }
}

lazy_static! {
    static ref DEVFS: Arc<DevFS> = Arc::new(DevFS {
        root: Arc::new(DevRootInode {}),
    });
}

pub fn InstallDevice(dev: Arc<dyn Device>) -> Result<(),i64> {
    let mut devices = DEVICES.lock();
    devices.push(dev);
    drop(devices);
    Ok(())
}

pub fn ReserveDeviceID() -> usize {
    NEXT_DEVICE.fetch_add(1, Ordering::SeqCst)
}

pub fn Initalize() {
    lazy_static::initialize(&DEVFS);
    VFS::Mount("/dev",DEVFS.clone());
}