use log::debug;

pub mod VFS;
pub mod RootFS;
pub mod DevFS;
pub mod InitrdFS;

pub fn InitalizeEarly() {
    RootFS::Initalize();
    DevFS::Initalize();
}

pub fn Initalize() {
    debug!("Finding root filesystem");
}