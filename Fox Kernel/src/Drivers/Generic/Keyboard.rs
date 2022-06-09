use alloc::sync::Arc;
use spin::Once;
use crate::FS::DevFS;
use crate::FS::VFS;

pub trait Keyboard: Send + Sync {
    fn Read(&self) -> Option<u8>;
    fn CanRead(&self) -> bool;
}

pub struct KeyboardDevice(usize);

impl DevFS::Device for KeyboardDevice {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        KEYBOARD_DEV.get().expect("device not ready").clone()
    }
}

impl VFS::Inode for KeyboardDevice {
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

            atime: unsafe {crate::UNIX_EPOCH as i64},
            mtime: unsafe {crate::UNIX_EPOCH as i64},
            ctime: unsafe {crate::UNIX_EPOCH as i64},
        })
    }
    fn GetName(&self) -> Result<&str, i64> {
        Ok("kbd")
    }
    fn Read(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        for i in 0..buffer.len() {
            let val = KEYBOARD.get().unwrap().Read();
            if val.is_none() {
                return i as i64;
            }
            buffer[i] = val.unwrap();
        }
        return buffer.len() as i64;
    }
}

pub static KEYBOARD: Once<Arc<dyn Keyboard>> = Once::new();
pub static KEYBOARD_DEV: Once<Arc<KeyboardDevice>> = Once::new();

pub fn Initalize() {
    if KEYBOARD.get().is_some() {
        DevFS::InstallDevice(KEYBOARD_DEV.call_once(|| Arc::new(KeyboardDevice(DevFS::ReserveDeviceID()))).clone());
    }
}