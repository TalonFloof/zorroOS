use opapi::file::*;
use pc_keyboard::{layouts, DecodedKey, Error, HandleControl, KeyState, KeyCode, KeyEvent, Keyboard, ScancodeSet1, ScancodeSet2};
use spin::Mutex;
use alloc::vec;
use core::sync::atomic::{AtomicBool,Ordering};

pub static ALT: AtomicBool = AtomicBool::new(false);
pub static CTRL: AtomicBool = AtomicBool::new(false);
pub static SHIFT: AtomicBool = AtomicBool::new(false);
pub static SESSION_STARTED: AtomicBool = AtomicBool::new(false);
pub static PTY_READY: AtomicBool = AtomicBool::new(false);

pub(crate) fn SetupConsole() -> bool {
    let con = opapi::syscall::open("/dev/liminecon",O_RDWR | O_CLOEXEC);
    if con.is_negative() {
        return false;
    }
    if opapi::syscall::dup2(con,1).is_negative() || opapi::syscall::dup2(con,2).is_negative() {
        return false;
    }
    return true;
}



pub enum KeyboardLayout {
    En_US_104QWERTY(Keyboard<layouts::Us104Key, ScancodeSet1>),
    En_GB_105QWERTY(Keyboard<layouts::Uk105Key, ScancodeSet1>),
    Generic_104DVORAK(Keyboard<layouts::Dvorak104Key, ScancodeSet1>),
}

impl KeyboardLayout {
    fn PushByte(&mut self, scancode: u8) -> Result<Option<KeyEvent>, Error> {
        match self {
            KeyboardLayout::En_US_104QWERTY(keyboard) => keyboard.add_byte(scancode),
            KeyboardLayout::En_GB_105QWERTY(keyboard) => keyboard.add_byte(scancode),
            KeyboardLayout::Generic_104DVORAK(keyboard) => keyboard.add_byte(scancode),
        }
    }

    fn HandleKeyEvent(&mut self, key_event: KeyEvent) -> Option<DecodedKey> {
        match self {
            KeyboardLayout::En_US_104QWERTY(keyboard) => keyboard.process_keyevent(key_event),
            KeyboardLayout::En_GB_105QWERTY(keyboard) => keyboard.process_keyevent(key_event),
            KeyboardLayout::Generic_104DVORAK(keyboard) => keyboard.process_keyevent(key_event),
        }
    }

    fn From(name: &str) -> Option<Self> {
        match name {
            "en_US_104qwerty" => Some(KeyboardLayout::En_US_104QWERTY(Keyboard::new(layouts::Us104Key, ScancodeSet1, HandleControl::MapLettersToUnicode))),
            "en_GB_105qwerty" => Some(KeyboardLayout::En_GB_105QWERTY(Keyboard::new(layouts::Uk105Key, ScancodeSet1, HandleControl::MapLettersToUnicode))),
            "generic_104dvorak" => Some(KeyboardLayout::Generic_104DVORAK(Keyboard::new(layouts::Dvorak104Key, ScancodeSet1, HandleControl::MapLettersToUnicode))),
            _ => None,
        }
    }
}

pub static KEYBOARD: Mutex<Option<KeyboardLayout>> = Mutex::new(None);

pub fn Loop() -> ! {
    {
        *KEYBOARD.lock() = Some(KeyboardLayout::From("en_US_104qwerty").unwrap());
    }
    if let Some(ref mut keyboard) = *KEYBOARD.lock() {
        let kbd = File::Open("/dev/kbd",O_RDWR | O_CLOEXEC).expect("NO KEYBOARD CHARACTER STREAM?");
        let pt_server = File::Open("/dev/ptmx",O_RDWR | O_CLOEXEC).expect("NO PTMX?");
        PTY_READY.store(true, Ordering::Relaxed);
        let mut buf = vec![0u8; 1];
        loop {
            let has_started = SESSION_STARTED.load(Ordering::Relaxed);
            if kbd.Read(&mut buf[0..=0]).ok().unwrap() > 0 {
                if let Ok(Some(key_event)) = keyboard.PushByte(buf[0]) {
                    match key_event.code {
                        KeyCode::AltLeft | KeyCode::AltRight => ALT.store(key_event.state == KeyState::Down, Ordering::Relaxed),
                        KeyCode::ShiftLeft | KeyCode::ShiftRight => SHIFT.store(key_event.state == KeyState::Down, Ordering::Relaxed),
                        KeyCode::ControlLeft | KeyCode::ControlRight => CTRL.store(key_event.state == KeyState::Down, Ordering::Relaxed),
                        _ => {}
                    }
                    let is_alt = ALT.load(Ordering::Relaxed);
                    let is_ctrl = CTRL.load(Ordering::Relaxed);
                    let is_shift = SHIFT.load(Ordering::Relaxed);
                    if let Some(key) = keyboard.HandleKeyEvent(key_event) {
                        match key {
                            DecodedKey::Unicode('\u{7f}') if is_alt && is_ctrl => {
                                SESSION_STARTED.store(true, Ordering::Relaxed);
                            },
                            DecodedKey::Unicode(c) => {
                                if has_started {
                                    buf[0] = c as u8;
                                    drop(pt_server.Write(&mut buf[0..=0]));
                                }
                            },
                            _ => {},
                        }
                    }
                }
                buf[0] = 0;
            }
            if let Ok(val) = pt_server.Read(buf.as_mut_slice()) {
                if val > 0 {
                    opapi::syscall::write(1,&buf[0..val]);
                }
            }
            opapi::syscall::sched_yield();
        }
    }
    panic!("NO KEYBOARD?");
}