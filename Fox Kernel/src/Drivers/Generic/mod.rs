pub mod UNIXStreamDevs;
pub mod PseudoTTY;
pub mod Keyboard;
pub mod Framebuffer;
pub mod UNIXPipe;

pub fn Initalize() {
    UNIXStreamDevs::Initalize();
    PseudoTTY::Initalize();
    Keyboard::Initalize();
    Framebuffer::Initalize();
}