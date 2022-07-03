use crate::FS::VFS;
use crate::FS::DevFS;
use alloc::sync::Arc;
use spin::Once;
use limine::*;
use crate::Memory::PageTable;

struct LimineTTY(usize,Option<&'static LimineTerminalResponse>);
impl LimineTTY {
    pub fn new() -> Arc<Self> {
        Arc::new(Self(DevFS::ReserveDeviceID(),crate::arch::TERMINAL.get_response().get()))
    }
}
impl DevFS::Device for LimineTTY {
    fn DeviceID(&self) -> usize {
        self.0
    }
    fn Inode(&self) -> Arc<dyn VFS::Inode> {
        TTY.get().expect("device not ready").clone()
    }
}

impl VFS::Inode for LimineTTY {
    fn Stat(&self) -> Result<VFS::Metadata, i64> {
        Ok(VFS::Metadata {
            inode_id: i64::MAX,
            mode: 0o0020600, // crw-------
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
        Ok("liminecon")
    }
    fn Open(&self, mode: usize) -> Result<(), i64> {
        if unsafe {crate::Console::QUIET} && mode != usize::MAX {
            TTY.get().unwrap().Write(0,b"\x1b[1;1H\x1b[2J");
            TTY.get().unwrap().IOCtl(1,0);
        }
        Ok(())
    }
    fn Read(&self, _offset: i64, _buffer: &mut [u8]) -> i64 {
        0
    }
    fn Write(&self, _offset: i64, buffer: &[u8]) -> i64 {
        let stri = alloc::string::String::from(alloc::string::String::from_utf8_lossy(buffer));
        let old_pt = x86_64::registers::control::Cr3::read();
        unsafe { crate::PageFrame::KernelPageTable.lock().Switch(); }
        let writer = self.1.unwrap().write().unwrap();
        let terminal = self.1.unwrap().terminals().unwrap().first().unwrap();
        writer(&terminal,stri.as_str());
        unsafe {x86_64::registers::control::Cr3::write(old_pt.0,old_pt.1);}
        return buffer.len() as i64;
    }
    fn IOCtl(&self, cmd: usize, _arg: usize) -> Result<usize, i64> {
        return match cmd {
            0x1 => { // FOXKERNEL_AMD64_LIMINETTYREDRAW
                let old_pt = x86_64::registers::control::Cr3::read();
                unsafe { crate::PageFrame::KernelPageTable.lock().Switch(); }
                let func = unsafe {*((self.1.unwrap() as *const _ as *const u64).offset(3) as *const extern "C" fn(terminal: *const LimineTerminal, addr: *const u8, len: u64))};
                let term = self.1.unwrap().terminals.get().unwrap().as_ptr().unwrap();
                func(term, core::ptr::null(), -4i64 as u64);
                unsafe {x86_64::registers::control::Cr3::write(old_pt.0,old_pt.1);}
                Ok(0)
            }
            _ => {
                Err(crate::Syscall::Errors::EINVAL as i64)
            }
        }
    }
}

static TTY: Once<Arc<LimineTTY>> = Once::new();

pub fn Initalize() {
    DevFS::InstallDevice(TTY.call_once(|| LimineTTY::new()).clone());
}