#![no_std]

extern crate alloc;

use alloc::boxed::Box;

pub trait ArchAPI {
    fn GetMachine(&self) -> Box<dyn MachineAPI>;
    //fn GetHarts();
}

pub trait Logger {
    fn log(&self, data: &str);
}

pub trait MachineAPI {
    fn GetLogger(&self) -> Box<dyn Logger>;
}