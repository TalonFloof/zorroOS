use alloc::borrow::ToOwned;
use core::ptr::NonNull;
use acpi::{AcpiTables, PhysicalMapping};
use stivale_boot::v2::StivaleRsdpTag;
use crate::arch::{APIC, HPET, PHYSMEM_BEGIN};
use acpi::AcpiHandler;
use acpi::hpet::HpetInfo;
use acpi::madt::Madt;
use log::{warn,info};
use spin::Mutex;
use alloc::vec::Vec;

extern crate acpi;

#[derive(Clone)]
#[doc(hidden)]
pub struct ACPIMapping {}
impl AcpiHandler for ACPIMapping {
    unsafe fn map_physical_region<T>(&self, physical_address: usize, size: usize) -> PhysicalMapping<Self, T> {
        PhysicalMapping::new(physical_address,NonNull::<T>::new(((physical_address as u64)+PHYSMEM_BEGIN) as *mut T).expect("Couldn't get address while mapping for ACPI"),size,size,self.to_owned())
    }
    fn unmap_physical_region<T>(_region: &PhysicalMapping<Self, T>) {}
}

pub static AML_TABLES: Mutex<Vec<&[u8]>> = Mutex::new(Vec::new());
pub static ACPI_TABLES: Mutex<Option<AcpiTables<ACPIMapping>>> = Mutex::new(None);

pub fn AnalyzeRSDP(tag: &StivaleRsdpTag) {
    if tag.rsdp == 0 {
        panic!("Your Firmware is not ACPI-Compliant");
    }
    unsafe {
        *ACPI_TABLES.lock() = Some(acpi::AcpiTables::from_rsdp(ACPIMapping {}, (tag.rsdp-PHYSMEM_BEGIN) as usize).expect("Your Firmware is not ACPI-Compliant"));
    }
    let mut acpilock = ACPI_TABLES.lock();
    let tables = acpilock.as_mut().unwrap();
    match tables.dsdt.as_ref() {
        Some(dsdt) => {
            unsafe {
                AML_TABLES.lock().push(core::slice::from_raw_parts((dsdt.address+PHYSMEM_BEGIN as usize) as *const u8,dsdt.length as usize));
            }
        }
        _ => {
            warn!("Couldn't find DSDT in ACPI! (Possible Firmware Bug)");
        }
    }
    for i in tables.ssdts.iter() {
        unsafe {AML_TABLES.lock().push(core::slice::from_raw_parts((i.address+PHYSMEM_BEGIN as usize) as *const u8,i.length as usize));}
    }
    let hpet: HpetInfo = HpetInfo::new(&tables).expect("Your motherboard doesn't have a HPET.");
    HPET::Setup(hpet);
    let madt = unsafe { tables.get_sdt::<Madt>(acpi::sdt::Signature::MADT).unwrap().unwrap() };
    let int_model = madt.parse_interrupt_model().unwrap();
    match int_model.0 {
        acpi::platform::interrupt::InterruptModel::Apic(a) => {
            unsafe { crate::arch::APIC::LAPIC_BASE = a.local_apic_address; }
            let mut count = 0;
            let mut lock = APIC::IOAPICs.lock();
            for i in a.io_apics.iter() {
                let mut entry = APIC::IOAPIC::new((i.address as usize)+PHYSMEM_BEGIN as usize,i.global_system_interrupt_base,0);
                entry.max_redirects = ((entry.Read(APIC::IOAPIC_REG_VERSION) >> 16) & 0xFF) + 1;
                lock[i.id as usize] = Some(entry);
                count += 1;
                
            }
            drop(lock);
            for j in 0..16 {
                APIC::IOAPIC_CreateRedirect(0x20+j,j,0,true);
            }
            info!("Found {} IOAPIC(s)", count);
            for i in a.interrupt_source_overrides.iter() {
                let mut flags = 0;
                match i.polarity {
                    acpi::platform::interrupt::Polarity::ActiveLow => {
                        flags = flags | APIC::IOAPIC_ACTIVE_LOW;
                    }
                    _ => {}
                }
                match i.trigger_mode {
                    acpi::platform::interrupt::TriggerMode::Level => {
                        flags = flags | APIC::IOAPIC_LEVEL_TRIGGER;
                    }
                    _ => {}
                }
                APIC::IOAPIC_CreateRedirect(0x20+i.isa_source as u32,i.global_system_interrupt,flags as u16,true);
                if i.isa_source as u32 != i.global_system_interrupt {
                    APIC::IOAPIC_CreateRedirect(0,i.isa_source as u32,0,false);
                }
            }
        }
        _ => {
            panic!("Error whilst parsing MADT");
        }
    }
    APIC::Enable();
    APIC::EnableTimer();
    drop(acpilock);
}