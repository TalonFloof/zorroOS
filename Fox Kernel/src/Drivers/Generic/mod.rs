pub mod UNIXStreamDevs;
pub mod PseudoTTY;
pub mod Keyboard;

pub fn Initalize() {
    UNIXStreamDevs::Initalize();
    PseudoTTY::Initalize();
    Keyboard::Initalize();
}