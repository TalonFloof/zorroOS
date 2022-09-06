use interfaces::MachineAPI;

pub struct APIImpl {

}

impl interfaces::ArchAPI for APIImpl {
    fn GetMachine(&self) -> alloc::boxed::Box<(dyn MachineAPI + 'static)> { todo!() }
}