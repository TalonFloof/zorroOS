pub mod UNIXStreamDevs;
pub mod PseudoTTY;
pub mod Keyboard;
pub mod Framebuffer;

pub fn Initalize() {
    UNIXStreamDevs::Initalize();
    PseudoTTY::Initalize();
    Keyboard::Initalize();
    Framebuffer::Initalize();
}