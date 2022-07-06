use crate::Framebuffer::MainFramebuffer;
use alloc::sync::Arc;
use spin::Once;
use crate::FS::DevFS;
use crate::FS::VFS;
use crate::Syscall::Errors;

pub struct Framebuffer(usize,i64);
impl Framebuffer {
    fn new() -> Arc<Self> {
        let fb = MainFramebuffer.lock();
        let size = fb.as_ref().unwrap().stride*fb.as_ref().unwrap().height;
        drop(fb);
        Arc::new(Self(DevFS::ReserveDeviceID(),size as i64))
    }
}

impl DevFS::Device for Framebuffer {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        FRAMEBUFFER_DEV.get().expect("device not ready").clone()
    }
}

impl VFS::Inode for Framebuffer {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            device_id: 0,
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
            reserved1: 0,
            reserved2: 0,
            reserved3: 0,
        })
    }
    fn GetName(&self) -> Result<&str, i64> {
        Ok("fb0")
    }
    fn Write(&self, offset: i64, buffer: &[u8]) -> i64 {
        if offset+buffer.len() as i64 > self.1 {
            return -(Errors::ENOSPC as i64);
        }
        let lock = MainFramebuffer.lock();
        unsafe {core::ptr::copy(buffer.as_ptr() as *const u8, (lock.as_ref().unwrap().pointer+offset as u64) as *mut u8, buffer.len());}
        drop(lock);
        buffer.len() as i64
    }
    fn IOCtl(&self, cmd: usize, _arg: usize) -> Result<usize, i64> {
        match cmd {
            0x5001 => { // IO_VID_WIDTH
                let val = MainFramebuffer.lock().as_ref().unwrap().width.clone();
                Ok(val)
            }
            0x5002 => { // IO_VID_HEIGHT
                let val = MainFramebuffer.lock().as_ref().unwrap().height.clone();
                Ok(val)
            }
            0x5003 => { // IO_VID_DEPTH
                let val = MainFramebuffer.lock().as_ref().unwrap().bpp.clone();
                Ok(val)
            }
            0x5007 => { // IO_VID_STRIDE
                let val = MainFramebuffer.lock().as_ref().unwrap().stride.clone();
                Ok(val)
            }
            _ => {return Err(Errors::EINVAL as i64);}
        }
    }
}

pub static FRAMEBUFFER_DEV: Once<Arc<Framebuffer>> = Once::new();

pub fn Initalize() {
    DevFS::InstallDevice(FRAMEBUFFER_DEV.call_once(|| Framebuffer::new()).clone());
}