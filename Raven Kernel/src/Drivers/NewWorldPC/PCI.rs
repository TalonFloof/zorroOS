use crate::print;
use spin::Mutex;
use alloc::vec::Vec;
use core::result::Result;
use crate::arch::PHYSMEM_BEGIN;
use x86_64::structures::port::{PortWrite,PortRead};

const PCI_VENDOR_ID: u16 = 0x00;
const PCI_DEVICE_ID: u16 = 0x02;
const PCI_COMMAND: u16 = 0x04;
const PCI_STATUS: u16 = 0x06;
#[allow(dead_code)]
const PCI_REVISION_ID: u16 = 0x08;
#[allow(dead_code)]
const PCI_SUBSYSTEM_ID: u16 = 0x2e;
const PCI_PROG_IF: u16 = 0x09;
const PCI_SUBCLASS: u16 = 0x0a;
const PCI_CLASS: u16 = 0x0b;
#[allow(dead_code)]
const PCI_CACHE_LINE_SIZE: u16 = 0x0c;
#[allow(dead_code)]
const PCI_LATENCY_TIMER: u16 = 0x0d;
#[allow(dead_code)]
const PCI_HEADER_TYPE: u16 = 0x0e;
#[allow(dead_code)]
const PCI_BIST: u16 = 0x0f;
const PCI_BAR0: u16 = 0x10;
#[allow(dead_code)]
const PCI_BAR1: u16 = 0x14;
#[allow(dead_code)]
const PCI_BAR2: u16 = 0x18;
#[allow(dead_code)]
const PCI_BAR3: u16 = 0x1c;
#[allow(dead_code)]
const PCI_BAR4: u16 = 0x20;
#[allow(dead_code)]
const PCI_BAR5: u16 = 0x24;
const PCI_INTERRUPT_LINE: u16 = 0x3c;
#[allow(dead_code)]
const PCI_INTERRUPT_PIN: u16 = 0x3d;
#[allow(dead_code)]
const PCI_SECONDARY_BUS: u16 = 0x19;

pub fn ReadU8(bus: u8, slot: u8, fun: u8, offset: u16) -> u8 {
    unsafe {u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    return (u32::read_from_port(0xCFC) >> ((offset & 0x3) * 8)) as u8 & 0xFF;}
}

pub fn ReadU16(bus: u8, slot: u8, fun: u8, offset: u16) -> u16 {
    unsafe {u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    return (u32::read_from_port(0xCFC) >> ((offset & 0x2) * 8)) as u16 & 0xFFFF;}
}

pub fn ReadU32(bus: u8, slot: u8, fun: u8, offset: u16) -> u32 {
    unsafe {u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    return u32::read_from_port(0xCFC);}
}

pub fn WriteU8(bus: u8, slot: u8, fun: u8, offset: u16, data: u8) {
    unsafe {let dat = ReadU32(bus,slot,fun,offset);
    u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    u32::write_to_port(0xCFC,(dat & !(0xFF << ((offset & 0x3) * 8))) | ((data as u32) << ((offset & 0x3) * 8)));}
}

pub fn WriteU16(bus: u8, slot: u8, fun: u8, offset: u16, data: u16) {
    unsafe {let dat = ReadU32(bus,slot,fun,offset);
    u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    u32::write_to_port(0xCFC,(dat & !(0xFFFF << ((offset & 0x2) * 8))) | ((data as u32) << ((offset & 0x2) * 8)));}
}

pub fn WriteU32(bus: u8, slot: u8, fun: u8, offset: u16, data: u32) {
    unsafe {u32::write_to_port(0xCF8,(((bus as u32) << 16) | ((slot as u32) << 11) | ((fun as u32) << 8) | ((offset as u32) & 0xFC) | 0x8000_0000) as u32);
    u32::write_to_port(0xCFC,data);}
}

pub fn ReadBAR(bus: u8, slot: u8, fun: u8, bar: u8) -> u64 {
    let addr = bar*4 + PCI_BAR0 as u8;
    let low = ReadU32(bus, slot, fun, addr as u16) as u64;
    let Type = low & 7;
    if Type == 0 {
        return low & (!0xf);
    }
    let high = ReadU32(bus,slot,fun,(addr+4) as u16) as u64;
    return (low & (!0xf)) | (high << 32);
}

pub fn PCIDevToString(class: u8, subclass: u8, progif: u8) -> &'static str {
    match class {
        0x1 => {
            match subclass {
                0 => {
                    return "scsi bus controller"
                }
                1 => {
                    return "ide controller"
                }
                2 => {
                    return "floppy disk drive controller"
                }
                3 => {
                    return "ipi bus controller"
                }
                4 => {
                    return "raid controller"
                }
                5 => {
                    return "ata controller"
                }
                6 => {
                    match progif {
                        0 => {
                            return "specific ahci controller"
                        }
                        1 => {
                            return "ahci sata controller"
                        }
                        2 => {
                            return "serial sata controller"
                        }
                        _ => {
                            return "unknown sata controller"
                        }
                    }
                }
                7 => {
                    return "serial scsi controller"
                }
                8 => {
                    match progif {
                        1 => {
                            return "nvmhci controller"
                        }
                        2 => {
                            return "NVMe controller"
                        }
                        _ => {
                            return "unknwon nvm controller"
                        }
                    }
                }
                _ => {
                    return "unknown mass storage controller"
                }
            }
        }
        0x2 => {
            match subclass {
                0 => {
                    return "ethernet controller"
                }
                1 => {
                    return "token ring controller"
                }
                2 => {
                    return "fddi controller"
                }
                3 => {
                    return "atm controller"
                }
                4 => {
                    return "isdn controller"
                }
                5 => {
                    return "worldfip controller"
                }
                6 => {
                    return "picmg controller"
                }
                7 => {
                    return "infiniband controller"
                }
                8 => {
                    return "fabric controller"
                }
                _ => {
                    return "unknown network controller"
                }
            }
        }
        0x3 => {
            match subclass {
                0 => {
                    return "VGA controller"
                }
                1 => {
                    return "XGA controller"
                }
                2 => {
                    return "3D controller"
                }
                _ => {
                    return "unknown display controller"
                }
            }
        }
        0x4 => {
            match subclass {
                _ => {
                    return "multimedia controller"
                }
            }
        }
        0x5 => {
            match subclass {
                _ => {
                    return "memory controller"
                }
            }
        }
        0x6 => {
            match subclass {
                0 => {
                    return "host bridge"
                }
                1 => {
                    return "isa bridge"
                }
                2 => {
                    return "eisa bridge"
                }
                3 => {
                    return "mca bridge"
                }
                4 => {
                    return "pci to pci bridge"
                }
                5 => {
                    return "pcmcia bridge"
                }
                6 => {
                    return "nubus bridge"
                }
                7 => {
                    return "cardbus bridge"
                }
                8 => {
                    return "raceway bridge"
                }
                9 => {
                    return "semi-transparent pci to pci bridge"
                }
                10 => {
                    return "infiniband to pci bridge"
                }
                _ => {
                    return "unknown bridge controller"
                }
            }
        }
        0x8 => {
            match subclass {
                _ => {
                    return "base system peripheral"
                }
            }
        }
        0xc => {
            match subclass {
                0 => {
                    match progif {
                        0 => {
                            return "generic firewire controller"
                        }
                        0x10 => {
                            return "oHCI firewire controller"
                        }
                        _ => {
                            return "unknown firewire controller"
                        }
                    }
                }
                1 => {
                    return "access bus controller"
                }
                2 => {
                    return "ssa controller"
                }
                3 => {
                    match progif {
                        0x00 => {
                            return "uHCI usb1 controller"
                        }
                        0x10 => {
                            return "oHCI usb1 controller"
                        }
                        0x20 => {
                            return "eHCI usb2 controller"
                        }
                        0x30 => {
                            return "xHCI usb3+ controller"
                        }
                        0xFE => {
                            return "usb device"
                        }
                        _ => {
                            return "unknown usb controller"
                        }
                    }
                }
                _ => {
                    return "unknown serial bus controller"
                }
            }
        }
        _ => {
            return "unclassified/unknown"
        }
    }
}

pub fn ValidDevice(bus: u8, slot: u8, func: u8) -> bool {
    let class = ReadU8(bus,slot,func,PCI_CLASS);
    return class == 0x1 || class == 0x2 || class == 0x3 || class == 0x4 || class == 0x5 || class == 0xc;
}

pub fn SearchCapability(bus: u8, slot: u8, func: u8, cap: u8) -> Result<u8,bool> {
    if ReadU8(bus,slot,func,PCI_STATUS) & 0x10 == 0x10 {
        let mut cap_off = ReadU8(bus,slot,func,0x34);
        while cap_off != 0 {
            if ReadU8(bus,slot,func,cap_off as u16) == cap {
                return Ok(cap_off);
            }
            cap_off = ReadU8(bus,slot,func,(cap_off+1) as u16);
        }
        return Err(true);
    }
    return Err(false);
}

pub fn EnableMSI(bus: u8, slot: u8, func: u8, off: u8) -> u8 {
    let msg_ctl = ((ReadU16(bus,slot,func,(off+2) as u16) & (!0x70)) & (!0x100)) | 0x1;
    let mut irqlock = IRQS_FREE.lock();
    let mut irql: u8 = 0;
    for i in 0..=0xCF {
        if !irqlock[i] {
            irql = (i as u8) + 0x30;
            irqlock[i] = true;
            break;
        }
    }
    drop(irqlock);
    if irql == 0 {
        return u8::MAX;
    }
    if msg_ctl & 0x80 == 0x80 {
        WriteU32(bus,slot,func,(off+0x4) as u16,0xFEE0_0000);
        WriteU32(bus,slot,func,(off+0x8) as u16,0x0);
        WriteU16(bus,slot,func,(off+0xC) as u16,irql as u16);
    } else {
        WriteU32(bus,slot,func,(off+0x4) as u16,0xFEE0_0000);
        WriteU16(bus,slot,func,(off+0x8) as u16,irql as u16);
    }
    WriteU16(bus,slot,func,(off+2) as u16,msg_ctl);
    return irql;
}

pub fn EnableMSIX(bus: u8, slot: u8, func: u8, off: u8) -> u8 {
    let msg_ctl = ReadU16(bus,slot,func,(off+2) as u16) | 0x8000;
    let mut irqlock = IRQS_FREE.lock();
    let mut irql: u8 = 0;
    for i in 0..=0xCF {
        if !irqlock[i] {
            irql = (i as u8) + 0x30;
            irqlock[i] = true;
            break;
        }
    }
    drop(irqlock);
    if irql == 0 {
        return u8::MAX;
    }
    let tab_pos = ReadU32(bus,slot,func,(off+4) as u16);
    let addr = (((ReadBAR(bus,slot,func,(tab_pos & 0x7) as u8)) + ((tab_pos as u64) & (!0x7)))+PHYSMEM_BEGIN) as *mut u64;
    unsafe {
        addr.offset(1).write_volatile(irql as u64);
        addr.write_volatile(0xFEE0_0000);
    }
    WriteU16(bus,slot,func,(off+2) as u16,msg_ctl);
    return irql;
}

pub struct PCIDevice {
    pub bus: u8,
    pub slot: u8,
    pub func: u8,
    pub vendor: u16,
    pub device: u16,
    pub class: u8,
    pub subclass: u8,
    pub progif: u8,
    pub irq: u8,
}

pub static PCI_DEVICES: Mutex<Vec<PCIDevice>> = Mutex::new(Vec::new());
static IRQS_FREE: Mutex<[bool; 0xD0]> = Mutex::new([false; 0xD0]);

pub fn Initalize() {
    print!("Scanning PCI Buses\n");
    let mut lock = PCI_DEVICES.lock();
    for bus in 0..=255 {
        for slot in 0..=31 {
            for func in 0..=7 {
                if ReadU16(bus,slot,func,PCI_VENDOR_ID) != 0xFFFF {
                    if ValidDevice(bus,slot,func) {
                        let vendor = ReadU16(bus,slot,func,PCI_VENDOR_ID);
                        let device = ReadU16(bus,slot,func,PCI_DEVICE_ID);
                        let class = ReadU8(bus,slot,func,PCI_CLASS);
                        let subclass = ReadU8(bus,slot,func,PCI_SUBCLASS);
                        let progif = ReadU8(bus,slot,func,PCI_PROG_IF);
                        let msicap = SearchCapability(bus,slot,func,0x5);
                        let msixcap = SearchCapability(bus,slot,func,0x11);
                        let mut irql = ReadU8(bus,slot,func,PCI_INTERRUPT_LINE);
                        WriteU16(bus,slot,func,PCI_COMMAND,ReadU16(bus,slot,func,PCI_COMMAND) | 0x6);
                        if msixcap.is_ok() {
                            irql = EnableMSIX(bus,slot,func,msixcap.ok().unwrap());
                            print!("├─[bus: 0x{:02x} slot: 0x{:02x} func: 0x{:02x}]\n│ vendor: 0x{:04x}\n│ device: 0x{:04x}\n│ msix-irq: 0x{:02x}\n│ type: {}\n", bus,slot,func,vendor,device,irql,PCIDevToString(class,subclass,progif));
                        } else if msicap.is_ok() {
                            irql = EnableMSI(bus,slot,func,msicap.ok().unwrap());
                            print!("├─[bus: 0x{:02x} slot: 0x{:02x} func: 0x{:02x}]\n│ vendor: 0x{:04x}\n│ device: 0x{:04x}\n│ msi-irq: 0x{:02x}\n│ type: {}\n", bus,slot,func,vendor,device,irql,PCIDevToString(class,subclass,progif));
                        } else if irql != 0xFF {
                            irql = irql + 0x20;
                            print!("├─[bus: 0x{:02x} slot: 0x{:02x} func: 0x{:02x}]\n│ vendor: 0x{:04x}\n│ device: 0x{:04x}\n│ isa-irq: 0x{:02x}\n│ type: {}\n", bus,slot,func,vendor,device,irql,PCIDevToString(class,subclass,progif));
                        } else {
                            print!("├─[bus: 0x{:02x} slot: 0x{:02x} func: 0x{:02x}]\n│ vendor: 0x{:04x}\n│ device: 0x{:04x}\n│ no-irq-support\n│ type: {}\n", bus,slot,func,vendor,device,PCIDevToString(class,subclass,progif));
                        }
                        lock.push(PCIDevice {
                            bus,
                            slot,
                            func,
                            vendor,
                            device,
                            class,
                            subclass,
                            progif,
                            irq: irql,
                        });
                    }
                }
            }
        }
    }
    drop(lock);
    print!("Finished PCI Scan\n");
}