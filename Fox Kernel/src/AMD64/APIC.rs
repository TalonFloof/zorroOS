use core::sync::atomic::{AtomicBool, Ordering};
use stivale_boot::v2::StivaleSmpTag;
use x86_64::registers::model_specific::Msr;
use crate::arch::{GDT, Timer, PHYSMEM_BEGIN};
use crate::PageFrame::Allocate;
use spin::Mutex;
use log::debug;

pub const LOCAL_APIC_ID: u32 = 0x20; // APIC ID Register
pub const LOCAL_APIC_VERSION: u32 = 0x30; // APIC Version Register
pub const LOCAL_APIC_TPR: u32 = 0x80; // Task Priority Register
pub const LOCAL_APIC_APR: u32 = 0x90; // Arbitration Priority Register
pub const LOCAL_APIC_PPR: u32 = 0xA0; // Processor Priority Register
pub const LOCAL_APIC_EOI: u32 = 0xB0; // Processor Priority Register
pub const LOCAL_APIC_RRD: u32 = 0xC0; // Remote Read Register
pub const LOCAL_APIC_LDR: u32 = 0xD0; // Logical Destination Register
pub const LOCAL_APIC_DFR: u32 = 0xE0; // Destination Format Register
pub const LOCAL_APIC_SIVR: u32 = 0xF0; // Spurious Interrupt Vector Register
pub const LOCAL_APIC_ISR: u32 = 0x100; // In-service Register
pub const LOCAL_APIC_TMR: u32 = 0x180; // Trigger Mode Register
pub const LOCAL_APIC_IRR: u32 = 0x200; // Interrupt Request Register
pub const LOCAL_APIC_ERROR_STATUS: u32 = 0x280; // Error Status Register
pub const LOCAL_APIC_ICR_LOW: u32 = 0x300; // Interrupt Command Register Low
pub const LOCAL_APIC_ICR_HIGH: u32 = 0x310; // Interrupt Command Register High
pub const LOCAL_APIC_LVT_TIMER: u32 = 0x320; // Timer Local Vector Table Entry
pub const LOCAL_APIC_LVT_PERF_MONITORING: u32 = 0x340; // Performance Local Vector Table Entry
pub const LOCAL_APIC_LVT_LINT0: u32 = 0x350; // Local Interrupt 0 Local Vector Table Entry
pub const LOCAL_APIC_LVT_LINT1: u32 = 0x360; // Local Interrupt 1 Local Vector Table Entry
pub const LOCAL_APIC_LVT_ERROR: u32 = 0x370; // Error Local Vector Table Entry
pub const LOCAL_APIC_TIMER_INITIAL_COUNT: u32 = 0x380; // Timer Initial Count Register
pub const LOCAL_APIC_TIMER_CURRENT_COUNT: u32 = 0x390; // Timer Current Count Register
pub const LOCAL_APIC_TIMER_DIVIDE: u32 = 0x3E0; // Timer Divide Configuration Register

pub const ICR_MESSAGE_TYPE_FIXED: u32 = 0;
pub const ICR_MESSAGE_TYPE_LOW_PRIORITY: u32 = 1 << 8;
pub const ICR_MESSAGE_TYPE_SMI: u32 = 2 << 8;
pub const ICR_MESSAGE_TYPE_REMOTE_READ: u32 = 3 << 8;
pub const ICR_MESSAGE_TYPE_NMI: u32 = 4 << 8;
pub const ICR_MESSAGE_TYPE_INIT: u32 = 5 << 8;
pub const ICR_MESSAGE_TYPE_STARTUP: u32 = 6 << 8;
pub const ICR_MESSAGE_TYPE_EXTERNAL: u32 = 7 << 8;

pub const ICR_DSH_DEST: u32 = 0;         // Use destination field
pub const ICR_DSH_SELF: u32 = 1 << 18; // Send to self
pub const ICR_DSH_ALL: u32 = 2 << 18;  // Send to ALL APICs
pub const ICR_DSH_OTHER: u32 = 3 << 18;// Send to all OTHER APICs

static mut IA32_LAPIC: Msr = Msr::new(0x1B);
pub(crate) static mut LAPIC_BASE: u64 = 0xfee00000;
pub static LAPIC_READY: AtomicBool = AtomicBool::new(false);
pub static LAPIC_HART_WAIT: AtomicBool = AtomicBool::new(false);

pub fn Enable() {
    unsafe {IA32_LAPIC.write(LAPIC_BASE | 0x800);}
    Write(LOCAL_APIC_TPR,0);
    Write(LOCAL_APIC_LDR,0);
    Write(LOCAL_APIC_LVT_TIMER,0x10000);
    Write(LOCAL_APIC_LVT_PERF_MONITORING,ICR_MESSAGE_TYPE_NMI);
    Write(LOCAL_APIC_SIVR, 0x1FF);
    LAPIC_READY.store(true,Ordering::SeqCst);
}

pub fn EnableTimer() {
    Write(LOCAL_APIC_TIMER_DIVIDE, 3);
    Write(LOCAL_APIC_TIMER_INITIAL_COUNT, 0xFFFFFFFF);
    Write(LOCAL_APIC_LVT_TIMER, 0x0);
    Timer::Sleep(10);
    Write(LOCAL_APIC_LVT_TIMER, 0x10000);
    let tick_in_10ms: u32 = 0xFFFFFFFF - Read(LOCAL_APIC_TIMER_CURRENT_COUNT);
    Write(LOCAL_APIC_TIMER_DIVIDE, 3);
    Write(LOCAL_APIC_TIMER_INITIAL_COUNT, tick_in_10ms);
    Write(LOCAL_APIC_LVT_TIMER, 32 | 0x20000);
}

pub fn Read(off: u32) -> u32 {
    unsafe {
        return ((LAPIC_BASE+PHYSMEM_BEGIN+off as u64) as *const u32).read_volatile();
    }
}

pub fn Write(off: u32, val: u32) {
    unsafe {((LAPIC_BASE+PHYSMEM_BEGIN+off as u64) as *mut u32).write_volatile(val);}
}

pub fn SendIPI(dest: u8, dsh: u32, Type: u32, vector: u8) {
    let high: u32 = (dest as u32) << 24;
    let low: u32 = dsh | Type | (vector as u32);
    Write(LOCAL_APIC_ICR_HIGH, high);
    Write(LOCAL_APIC_ICR_LOW, low);
}
pub fn SendIPIWait(dest: u8, dsh: u32, Type: u32, vector: u8) {
    let high: u32 = (dest as u32) << 24;
    let low: u32 = dsh | Type | (vector as u32);
    Write(LOCAL_APIC_ICR_HIGH, high);
    Write(LOCAL_APIC_ICR_LOW, low);
    while Read(LOCAL_APIC_ICR_LOW) & (1 << 12) == 1 << 12 { core::hint::spin_loop(); }
}

pub fn EnableHarts(smp: &mut StivaleSmpTag) {
    unsafe {
        for i in smp.as_slice_mut() {
            if i.lapic_id != 0 {
                LAPIC_HART_WAIT.store(true,Ordering::SeqCst);
                let mut hart = GDT::Hart::new();
                hart.scdata[2] = i.lapic_id as u64;
                let stack = Allocate(0x4000).unwrap() as u64;
                hart.set_rsp0(stack+0x4000);
                GDT::HARTS[i.lapic_id as usize] = Some(hart);
                debug!("hart 0x{:02x} rip=0x{:016x},rsp=0x{:016x}", i.lapic_id,(crate::arch::_Hart_start as *mut u8) as u64,stack+0x4000);
                i.target_stack = stack+0x4000;
                i.goto_address = (crate::arch::_Hart_start as *mut u8) as u64;
                while LAPIC_HART_WAIT.load(Ordering::SeqCst) {
                    core::hint::spin_loop();
                }
            }
        }
    }
}

//////////////////////// IOAPIC

pub static IOAPICs: Mutex<[Option<IOAPIC>; 256]> = Mutex::new([None; 256]);

pub const IOAPIC_REG_VERSION: u32 = 0x1;
pub const IOAPIC_REG_REDIRECT_BASE: u32 = 0x10;

#[derive(Clone, Copy)]
pub struct IOAPIC {
    pub base: usize,
    pub int_base: u32,
    pub max_redirects: u32,
}

impl IOAPIC {
    pub fn new(base: usize, irq: u32, size: u32) -> Self {
        Self {
            base,
            int_base: irq,
            max_redirects: size,
        }
    }
    pub fn Read(&self, reg: u32) -> u32 {
        unsafe {((self.base+0) as *mut u32).write_volatile(reg);
        return ((self.base+16) as *mut u32).read_volatile(); }
    }
    pub fn Write(&self, reg: u32, val: u32) {
        unsafe {((self.base+0) as *mut u32).write_volatile(reg);
        ((self.base+16) as *mut u32).write_volatile(val);}
    }
    pub fn ContainsGSI(&self, gsi: u32) -> bool {
        return gsi >= self.int_base && gsi < self.int_base+self.max_redirects;
    }
}

/*
vector 0-7
deliverymode 8-10 (000: Fixed 001: Low Priority)
destmode 11 (0: Physical 1: Logical)
delivstatus 12 (Ignore)
pinpolarity 13 (0: Active High 1: Active Low)
remoteirr 14 (No Idea what this does...)
triggermode 15 (0: Edge 1: Level. ISA is usually Active High Edge unless overwritten)
mask 16
dest 56-63
*/

pub const IOAPIC_ACTIVE_LOW: u64 = 1 << 13;
pub const IOAPIC_LEVEL_TRIGGER: u64 = 1 << 15; 

pub fn IOAPIC_From_GSI(gsi: u32) -> usize {
    let lock = IOAPICs.lock();
    for (i,j) in lock.iter().enumerate() {
        if j.is_some() {
            if j.unwrap().ContainsGSI(gsi) {
                drop(lock);
                return i;
            }
        }
    }
    drop(lock);
    panic!("Couldn't find IOAPIC for GSI 0x{}", gsi);
}

pub fn IOAPIC_CreateRedirect(int_id: u32, int_base: u32, flags: u16, enable: bool) {
    let target = IOAPIC_From_GSI(int_base);
    let lock = IOAPICs.lock();
    let apic = lock[target].unwrap();
    let entry: u64 = (int_id as u64) | (flags as u64) | (if !enable {1 << 16} else {0});
    let interrupt_offset: u32 = int_base - apic.int_base;
    let target_io_offset: u32 = interrupt_offset * 2;
    apic.Write(IOAPIC_REG_REDIRECT_BASE + target_io_offset,(entry & (u32::MAX as u64)) as u32);
    apic.Write(IOAPIC_REG_REDIRECT_BASE + target_io_offset + 1,(entry >> 32) as u32);
    drop(lock);
}