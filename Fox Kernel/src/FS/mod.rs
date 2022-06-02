use log::debug;

pub mod VFS;
pub mod RootFS;
pub mod DevFS;
pub mod InitrdFS;

pub fn Initalize() {
    debug!("Registering filesystems...");
    RootFS::Initalize();
    DevFS::Initalize();
}
