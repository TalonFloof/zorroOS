use aml::AmlContext;
use aml::Handler;
use crate::arch::PHYSMEM_BEGIN;
use x86_64::structures::port::{PortRead,PortWrite};
use spin::Mutex;
use alloc::boxed::Box;

pub struct AMLImplementation {}

impl Handler for AMLImplementation {
    fn read_u8(&self, address: usize) -> u8 {
        unsafe {*((address+PHYSMEM_BEGIN as usize) as *const u8)}
    }
    fn read_u16(&self, address: usize) -> u16 {
        unsafe {*((address+PHYSMEM_BEGIN as usize) as *const u16)}
    }
    fn read_u32(&self, address: usize) -> u32 {
        unsafe {*((address+PHYSMEM_BEGIN as usize) as *const u32)}
    }
    fn read_u64(&self, address: usize) -> u64 {
        unsafe {*((address+PHYSMEM_BEGIN as usize) as *const u64)}
    }
    fn write_u8(&mut self, address: usize, value: u8) {
        unsafe {((address+PHYSMEM_BEGIN as usize) as *mut u8).write(value);}
    }
    fn write_u16(&mut self, address: usize, value: u16) {
        unsafe {((address+PHYSMEM_BEGIN as usize) as *mut u16).write(value);}
    }
    fn write_u32(&mut self, address: usize, value: u32) {
        unsafe {((address+PHYSMEM_BEGIN as usize) as *mut u32).write(value);}
    }
    fn write_u64(&mut self, address: usize, value: u64) {
        unsafe {((address+PHYSMEM_BEGIN as usize) as *mut u64).write(value);}
    }
    fn read_io_u8(&self, port: u16) -> u8 {
        unsafe {u8::read_from_port(port)}
    }
    fn read_io_u16(&self, port: u16) -> u16 {
        unsafe {u16::read_from_port(port)}
    }
    fn read_io_u32(&self, port: u16) -> u32 {
        unsafe {u32::read_from_port(port)}
    }
    fn write_io_u8(&self, port: u16, value: u8) {
        unsafe {u8::write_to_port(port,value);}
    }
    fn write_io_u16(&self, port: u16, value: u16) {
        unsafe {u16::write_to_port(port,value);}
    }
    fn write_io_u32(&self, port: u16, value: u32) {
        unsafe {u32::write_to_port(port,value);}
    }
    fn read_pci_u8(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16
    ) -> u8 {
        crate::Drivers::Arch::PCI::ReadU8(bus,device,function,offset)
    }
    fn read_pci_u16(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16
    ) -> u16 {
        crate::Drivers::Arch::PCI::ReadU16(bus,device,function,offset)
    }
    fn read_pci_u32(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16
    ) -> u32 {
        crate::Drivers::Arch::PCI::ReadU32(bus,device,function,offset)
    }
    fn write_pci_u8(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16, 
        value: u8
    ) {
        crate::Drivers::Arch::PCI::WriteU8(bus,device,function,offset,value);
    }
    fn write_pci_u16(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16, 
        value: u16
    ) {
        crate::Drivers::Arch::PCI::WriteU16(bus,device,function,offset,value);
    }
    fn write_pci_u32(
        &self, 
        _segment: u16, 
        bus: u8, 
        device: u8, 
        function: u8, 
        offset: u16, 
        value: u32
    ) {
        crate::Drivers::Arch::PCI::WriteU32(bus,device,function,offset,value);
    }
}

static AML_CONTEXT: Mutex<Option<AmlContext>> = Mutex::new(None);

pub fn Initalize() {
    let mut lock = AML_CONTEXT.lock();
    *lock = Some(AmlContext::new(Box::new(AMLImplementation {}),aml::DebugVerbosity::None));
    let amlconx = lock.as_mut().unwrap();
    let arlock = crate::arch::ACPI::AML_TABLES.lock();
    for i in arlock.iter() {
        amlconx.parse_table(i);
    }
    amlconx.initialize_objects();
    drop(lock);
}