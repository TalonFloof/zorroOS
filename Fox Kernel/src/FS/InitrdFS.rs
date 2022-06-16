use crate::FS::VFS;
use alloc::vec::Vec;
use alloc::string::String;
use alloc::sync::Arc;
use lazy_static::lazy_static;
use crate::Syscall::Errors;
use crate::FS::TmpFS::TMPInode;

pub struct InitrdFS;

impl VFS::Filesystem for InitrdFS {
    fn GetRootInode(&self) -> Arc<dyn VFS::Inode> {
        ROOT_INODE.clone()
    }
    fn UMount(&self) -> i64 {
        0
    }
}

lazy_static! {
    static ref ROOT_INODE: Arc<TMPInode> = TMPInode::new(1,String::from(""),0o0040755,None);
}

// Only use this if the bootloader provided a Ramdisk / Ramdisks.
pub fn Initalize(ramdisks: Vec<(String,&[u8])>) {
    lazy_static::initialize(&ROOT_INODE);
    for (name,data) in ramdisks.iter() {
        if !name.starts_with("Mod") {
            for entry in cpio_reader::iter_files(data) {
                log::debug!("{}", if entry.name().ends_with("...") {entry.name().strip_suffix("...").unwrap()} else {entry.name()});
                let path: Vec<_> = entry.name().split("/").filter(|e| *e != "" && *e != ".").collect();
                let mut cwd: Arc<dyn VFS::Inode> = ROOT_INODE.clone();
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
