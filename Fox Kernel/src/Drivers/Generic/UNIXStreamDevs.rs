use crate::FS::VFS;
use crate::FS::DevFS;
use alloc::sync::Arc;
use spin::Once;

struct Null(usize);
impl Null {
    fn new() -> Arc<Self> {
        Arc::new(Self(DevFS::ReserveDeviceID()))
    }
}
impl DevFS::Device for Null {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        NULL.get().expect("device not ready").clone()
    }
}
impl VFS::Inode for Null {
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
        Ok("null")
    }
    fn Read(&self, _offset: i64, _buffer: &mut [u8]) -> i64 {
        0
    }
    fn Write(&self, _offset: i64, _buffer: &[u8]) -> i64 {
        0
    }
}

struct Zero(usize);
impl Zero {
    fn new() -> Arc<Self> {
        Arc::new(Self(DevFS::ReserveDeviceID()))
    }
}
impl DevFS::Device for Zero {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        ZERO.get().expect("device not ready").clone()
    }
}
impl VFS::Inode for Zero {
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
        Ok("zero")
    }
    fn Read(&self, _offset: i64, buffer: &mut [u8]) -> i64 {
        buffer.fill(0);
        buffer.len() as i64
    }
    fn Write(&self, _offset: i64, _buffer: &[u8]) -> i64 {
        0
    }
}

static NULL: Once<Arc<Null>> = Once::new();
static ZERO: Once<Arc<Zero>> = Once::new();

pub fn Initalize() {
    DevFS::InstallDevice(NULL.call_once(|| Null::new()).clone());
    DevFS::InstallDevice(ZERO.call_once(|| Zero::new()).clone());
}