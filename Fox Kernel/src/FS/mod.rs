use alloc::vec::Vec;
use alloc::string::String;

pub mod VFS;
pub mod DevFS;
pub mod InitrdFS;
pub mod TmpFS;

pub fn InitalizeEarly() {
    DevFS::Initalize();
}

pub fn Initalize(ramdisks: Vec<(String,&[u8])>) {
    if let Some(searchtype) = crate::CommandLine::OPTIONS.get().unwrap().get("--root.type") {
        match searchtype {
            &"initrd" => {
                if ramdisks.len() > 0 {
                    log::info!("Loading Provided RAM Disk(s)...");
                    InitrdFS::Initalize(ramdisks);
                    return;
                } else {
                    log::error!("Bootloader expects us to mount RAM Disk(s) as root, but the bootloader didn't give us any!");
                }
            },
            &"scan" => {
                log::error!("--root.type=scan is not supported yet!");
            },
            _ => {
                log::error!("Bootloader didn't specify how to detect root filesystem!");
            }
        }
    }
    log::warn!("Fox Kernel will now halt");
    crate::halt_other_harts!();
    crate::halt!();
}