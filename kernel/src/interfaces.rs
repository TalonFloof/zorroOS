use alloc::boxed::Box;

pub trait ArchAPI {
    fn GetMachine() -> Box<dyn MachineAPI>;
    //fn GetHarts();
}

pub trait Logger {
    fn log(data: &str);
}

pub trait MachineAPI {
    fn GetLogger() -> Box<dyn Logger>;
}