pub mod Keyboard {
    use x86_64::structures::port::{PortRead,PortWrite};
    // PS/2 Keyboard Command Port: 0x64
    // PS/2 Keyboard Data Port: 0x60
    pub fn Initalize() {
        unsafe {
            while u8::read_from_port(0x64) & 0x1 == 0x1 {
                u8::read_from_port(0x60);
            }
            u8::write_to_port(0x64,0xae);                    // Enable first PS/2 Port (Keyboard)
            u8::write_to_port(0x64,0x20);                    // Disable First PS/2 port clock & Enable First PS/2 port interrupt
            let status = u8::read_from_port(0x60);
            if status & 0x4 != 0x4 {
                log::warn!("System Flag on PS/2 Controller is clear! (Should be set if POST passes)");
            }
            u8::write_to_port(0x64,0x60);
            u8::write_to_port(0x60,(status | 1) & (!0x10u8));
            u8::write_to_port(0x60,0xf4);
            let mut lock = crate::arch::IDT::IRQ_HANDLERS.lock();
            lock[0x1] = Some(Handle);
            drop(lock);
        }
    }
    pub fn Read() -> Option<u8> {
        return None;
    }
    pub fn Handle() {
        unsafe {
            while u8::read_from_port(0x64) & 0x1 == 0x1 {
                u8::read_from_port(0x60);
            }
        }
    }
}

pub mod Mouse {

}

pub fn Initalize() {
    Keyboard::Initalize();
}