#[cfg(target_arch="x86_64")]
#[path = "NewWorldPC/mod.rs"]
pub mod Arch;

pub fn Initalize() {
    Arch::Initalize();
}