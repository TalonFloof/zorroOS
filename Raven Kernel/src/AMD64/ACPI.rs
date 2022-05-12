use alloc::borrow::ToOwned;
use core::ptr::NonNull;
use acpi::{AcpiTables, PhysicalMapping};
use stivale_boot::v2::StivaleRsdpTag;
use crate::arch::{APIC, HPET, PHYSMEM_BEGIN};
use acpi::AcpiHandler;
use acpi::hpet::HpetInfo;
use acpi::madt::Madt;
use crate::print;

extern crate acpi;

#[derive(Clone)]
struct ACPIMapping {}
impl AcpiHandler for ACPIMapping {
    unsafe fn map_physical_region<T>(&self, physical_address: usize, size: usize) -> PhysicalMapping<Self, T> {
        PhysicalMapping::new(physical_address,NonNull::<T>::new(((physical_address as u64)+PHYSMEM_BEGIN) as *mut T).expect("Couldn't get address while mapping for ACPI"),size,size,self.to_owned())
    }
    fn unmap_physical_region<T>(_region: &PhysicalMapping<Self, T>) {}
}

pub fn AnalyzeRSDP(tag: &StivaleRsdpTag) {
    let tables: AcpiTables<ACPIMapping>;
    unsafe {
        tables = acpi::AcpiTables::from_rsdp(ACPIMapping {}, (tag.rsdp-PHYSMEM_BEGIN) as usize).expect("No XSDT From RSDP...");
    }
    let hpet: HpetInfo = HpetInfo::new(&tables).expect("Your motherboard appears to use a PIIX-based chipset.\
    \nThe Raven Kernel isn't compatible with this chipset.\
    \nPlease use a motherboard with an ICH-based chipset.");
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
            print!("Found {} IOAPIC(s)\n", count);
            for i in a.interrupt_source_overrides.iter() {
                print!("ISA Redirect: ISAIRQ 0x{:x} -> GSI 0x{:x}\n", i.isa_source, i.global_system_interrupt);
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
}