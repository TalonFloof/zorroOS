pub mod PCI;
pub mod PS2HID;
pub mod ACPI;

pub fn Initalize() {
    PCI::Initalize();
    ACPI::Initalize();
    PS2HID::Initalize();
}