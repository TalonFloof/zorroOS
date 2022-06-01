pub mod UNIXStreamDevs;
pub mod PseudoTTY;

pub fn Initalize() {
    UNIXStreamDevs::Initalize();
    PseudoTTY::Initalize();
}