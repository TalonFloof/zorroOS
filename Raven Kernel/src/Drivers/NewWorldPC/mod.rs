pub mod PCI;
#[path = "../OldWorldPC/PS2HID.rs"]
pub mod PS2HID;

pub fn Initalize() {
    PCI::Initalize();
    PS2HID::Initalize();
}