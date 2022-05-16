use crate::print;

pub mod VFS;
pub mod RootFS;

pub fn Initalize() {
    print!("Registering filesystems...\n");
    RootFS::Initalize();
}
