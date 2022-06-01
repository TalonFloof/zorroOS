use core::num::NonZeroUsize;
use xhci::accessor::Mapper;
use core::sync::atomic::{AtomicUsize,Ordering};
use spin::Mutex;

#[derive(Clone)]
struct MemoryMapper;
impl Mapper for MemoryMapper {
    unsafe fn map(&mut self, phys_base: usize, _bytes: usize) -> NonZeroUsize {
        NonZeroUsize::new(crate::arch::PHYSMEM_BEGIN as usize+(phys_base.div_floor(0x1000) * 0x1000)).unwrap()
    }
    fn unmap(&mut self, _virt_base: usize, _bytes: usize) {
        // Unmapping isn't supported
    }
}


pub struct xHCI_Device {
    regs: xhci::Registers<MemoryMapper>,
    caps: Option<xhci::extended_capabilities::List<MemoryMapper>>,
    irql: u16,
}

impl xHCI_Device {
    pub fn new(base: usize, irql: u16) -> Self {
        let r: xhci::Registers<MemoryMapper> = unsafe {xhci::Registers::new(base,MemoryMapper)};
        let hc1 = r.capability.hccparams1.read_volatile();
        Self {
            regs: r,
            caps: unsafe {xhci::extended_capabilities::List::new(base, hc1, MemoryMapper)},
            irql,
        }
    }
    pub fn Init(&mut self) {
        // Release Control from Firmware (if it didn't already do that for us)
        if let Some(caplist) = self.caps.as_mut() {
            for i in caplist {
                if let Ok(cap) = i {
                    match cap {
                        xhci::extended_capabilities::ExtendedCapability::UsbLegacySupport(c) => {
                            log::debug!("Releasing xHCI from Firmware");
                            /*c.usblegsup.update_volatile(|u| {
                                //u.set_
                            })*/
                        }
                        _ => {}
                    }
                }
            }
        }

        // Startup Controller
        self.regs.operational.usbcmd.update_volatile(|u| {
            u.set_run_stop();
        });
        while self.regs.operational.usbsts.read_volatile().hc_halted() {core::hint::spin_loop();}
    }
}

pub static XHCI_CONTROLLER: Mutex<Option<xHCI_Device>> = Mutex::new(None);
static XHCI_BASE: AtomicUsize = AtomicUsize::new(0);

pub fn Initalize() {
    let lock = crate::Drivers::Arch::PCI::PCI_DEVICES.lock();
    for i in lock.iter() {
        if i.class == 0xc && i.subclass == 0x3 && i.progif == 0x30 {
            let base = crate::Drivers::Arch::PCI::ReadBAR(i.bus,i.slot,i.func,0);
            XHCI_BASE.store(base as usize,Ordering::SeqCst);
            if base > crate::PageFrame::Pages.load(Ordering::SeqCst)*0x1000 && crate::PageFrame::Pages.load(Ordering::SeqCst)*0x1000 > u32::MAX as u64 {
                return;
            }
            log::debug!("Starting up xHCI Controller");
            if let crate::Drivers::Arch::PCI::IRQ::Msix(irq) = i.irq {
                *XHCI_CONTROLLER.lock() = Some(xHCI_Device::new(base as usize,irq as u16));
                XHCI_CONTROLLER.lock().as_mut().unwrap().Init();
            } else if let crate::Drivers::Arch::PCI::IRQ::Msi(irq) = i.irq {
                *XHCI_CONTROLLER.lock() = Some(xHCI_Device::new(base as usize,irq as u16));
                XHCI_CONTROLLER.lock().as_mut().unwrap().Init();
            } else {
                log::warn!("xHCI Controller doesn't support MSI or MSI-X, cannot startup!");
            }
        }
    }
}