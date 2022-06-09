use crate::Drivers::Generic::Keyboard;

pub struct PS2KBD;

impl Keyboard::Keyboard for PS2KBD {
    fn Read(&self) -> Option<u8> {
        PS2Keyboard::BUFFER.lock().pop_front()
    }
    fn CanRead(&self) -> bool {
        let buf = PS2Keyboard::BUFFER.lock();
        if buf.len() == 0 {
            drop(buf);
            return false;
        }
        drop(buf);
        return true;
    }
}

pub mod PS2Keyboard {
    use x86_64::structures::port::{PortRead,PortWrite};
    use spin::Mutex;
    use alloc::collections::VecDeque;
    use super::PS2KBD;
    use alloc::sync::Arc;
    use crate::Drivers::Generic::Keyboard;
    // PS/2 Keyboard Command Port: 0x64
    // PS/2 Keyboard Data Port: 0x60
    lazy_static::lazy_static! {
        pub static ref BUFFER: Mutex<VecDeque<u8>> = Mutex::new(VecDeque::new());
    }
    pub fn Initalize() {
        unsafe {
            log::debug!("Initalizing PS/2 Keyboard");
            while u8::read_from_port(0x64) & 0x1 == 0x1 {
                u8::read_from_port(0x60);
            }
            SendCommand(0xf0);
            SendCommand(1);
            Keyboard::KEYBOARD.call_once(|| Arc::new(PS2KBD));
            let mut lock = crate::arch::IDT::IRQ_HANDLERS.lock();
            lock[0x1] = Some(Handle);
            drop(lock);
        }
    }
    pub fn Wait() {
        let mut timeout = 10000;
        while timeout > 0 {
            timeout -= 1;
            unsafe {
                if u8::read_from_port(0x64) & 0x2 != 0x2 {
                    return;
                }
            }
        }
    }
    pub fn SendCommand(cmd: u8) -> u8 {
        let mut retries = 3;
        let mut val = 0;
        while val == 0xfe && retries > 0 {
            retries -= 1;
            Wait();
            unsafe {u8::write_to_port(0x60,cmd);}
            val = unsafe {u8::read_from_port(0x60)};
        }
        return val;
    }
    pub fn Handle() {
        unsafe {
            while u8::read_from_port(0x64) & 0x1 == 0x1 {
                let mut lock = BUFFER.lock();
                let val = u8::read_from_port(0x60);
                if val == 0x00 || val == 0xAA || val == 0xEE || val >= 0xFA {
                    continue;
                }
                if lock.len() >= 128 {
                    lock.pop_front();
                }
                lock.push_back(val);
                drop(lock);
            }
        }
    }
}

pub mod PS2Mouse {

}

pub fn Initalize() {
    PS2Keyboard::Initalize();
}