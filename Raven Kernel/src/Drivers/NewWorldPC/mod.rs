pub mod PCI;
pub mod PS2HID;

pub fn Initalize() {
    PCI::Initalize();
    PS2HID::Initalize();
}