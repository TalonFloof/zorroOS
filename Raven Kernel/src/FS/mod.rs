use log::info;

pub mod VFS;
pub mod RootFS;
pub mod DevFS;

pub fn Initalize() {
    info!("Registering filesystems...");
    RootFS::Initalize();
    DevFS::Initalize();
}
