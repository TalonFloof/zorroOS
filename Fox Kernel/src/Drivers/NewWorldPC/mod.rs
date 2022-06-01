pub mod PCI;
#[path = "../OldWorldPC/PS2HID.rs"]
pub mod PS2HID;
#[path = "../OldWorldPC/ATA.rs"]
pub mod ATA;
pub mod AHCI;
pub mod xHCI;

pub fn Initalize() {
    PCI::Initalize();
    PS2HID::Initalize();
    ATA::Initalize();
    xHCI::Initalize();
}