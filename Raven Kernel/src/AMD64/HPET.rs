use acpi::HpetInfo;
use crate::arch::PHYSMEM_BEGIN;

static mut BASE: u64 = 0;
static mut CLOCK: u64 = 0;

const HPET_GENERAL_CAPABILITIES: u64 = 0;
const HPET_GENERAL_CONFIGURATION: u64 = 16;
const HPET_MAIN_COUNTER_VALUE: u64 = 240;

pub fn Setup(hpet: HpetInfo) {
    unsafe {BASE = hpet.base_address as u64;}
    unsafe {CLOCK=Read(HPET_GENERAL_CAPABILITIES) >> 32;}
    Write(HPET_GENERAL_CONFIGURATION,0);
    Write(0x100, (Read(0x100) | (1 << 6)) & !0b100);
    Write(HPET_MAIN_COUNTER_VALUE,0);
    Write(HPET_GENERAL_CONFIGURATION,1);
}

fn Read(reg: u64) -> u64 {
    unsafe {return ((BASE+reg+PHYSMEM_BEGIN) as *const u64).read_volatile()};
}

fn Write(reg: u64, val: u64) {
    unsafe {((BASE+reg+PHYSMEM_BEGIN) as *mut u64).write_volatile(val);}
}

pub fn Sleep(ms: isize) {
    unsafe {
        let target: u64 = Read(HPET_MAIN_COUNTER_VALUE) + (ms as u64 * (1000000000000 / CLOCK));
        while Read(HPET_MAIN_COUNTER_VALUE) < target {
            core::hint::spin_loop();
        };
    }
}