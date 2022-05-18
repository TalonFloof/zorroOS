#[macro_use]
pub mod UART;

pub mod Memory;
pub mod IDT;
pub mod GDT;
pub mod APIC;
pub mod ACPI;
pub mod HPET;
pub mod Task;
pub mod Syscall;

extern crate stivale_boot;
extern crate x86_64;

use core::arch::asm;
use core::sync::atomic::Ordering;
use stivale_boot::v2::*;
use crate::Memory::PageTable;
use crate::print_startup_message;
use crate::Scheduler::SCHEDULER_STARTED;
use log::info;

pub const PHYSMEM_BEGIN: u64 = 0xFFFF_8000_0000_0000;

#[macro_export]
macro_rules! halt {
	() => {
		unsafe { core::arch::asm!("hlt"); }
	}
}

#[inline(always)]
pub fn CurrentHart() -> u32 {
	crate::arch::APIC::Read(crate::arch::APIC::LOCAL_APIC_ID) >> 24
}
#[macro_export]
macro_rules! halt_other_harts {
	() => {
		x86_64::instructions::interrupts::disable();
		unsafe {crate::Console::WRITER.force_unlock();}
		if crate::arch::APIC::LAPIC_READY.load(core::sync::atomic::Ordering::SeqCst) {
			crate::arch::APIC::SendIPI(crate::arch::CurrentHart() as u8,crate::arch::APIC::ICR_DSH_OTHER,crate::arch::APIC::ICR_MESSAGE_TYPE_NMI,0);
		}
	}
}

#[no_mangle]
extern "C" fn _start(pmr: &mut StivaleStruct) {
    unsafe { asm!("cli"); };
    UART::Setup();
	print_startup_message!();
	GDT::Setup();
	unsafe { IDT::Setup(); }
	Syscall::Initialize();
	Task::SetupFPU();
	Memory::AnalyzeMMAP(
		pmr.memory_map().expect("The Raven Kernel requires that the Stivale2 compatible bootloader that you are using contains a memory map."));
	if pmr.framebuffer().is_some() {
		let fb_tag = pmr.framebuffer().unwrap();
		crate::Framebuffer::Init(fb_tag.framebuffer_addr as *mut u32,fb_tag.framebuffer_width as usize,fb_tag.framebuffer_height as usize,fb_tag.framebuffer_pitch as usize,fb_tag.framebuffer_bpp as usize);
	}
	ACPI::AnalyzeRSDP(
		pmr.rsdp().expect("The Raven Kernel requires that the Stivale2 compatible bootloader that you are using contains a pointer to the ACPI tables."));
	APIC::EnableHarts(
		pmr.smp_mut().expect("The Raven Kernel requires that the Stivale2 compatible bootloader that you are using is compatable with the SMP feature."));
	let free = crate::PageFrame::FreeMem.load(core::sync::atomic::Ordering::SeqCst);
	let total = crate::PageFrame::TotalMem.load(core::sync::atomic::Ordering::SeqCst);
	info!("{} MiB Used out of {} MiB Total", (total-free)/1024/1024, total/1024/1024);
	crate::main();
}

extern "C" fn _Hart_start(smp: &'static StivaleSmpInfo) -> ! {
	unsafe {GDT::HARTS[smp.lapic_id as usize].as_mut().unwrap().init()}
	unsafe {IDT::Setup();}
	Syscall::Initialize();
	Task::SetupFPU();
	unsafe {(*crate::PageFrame::KernelPageTable.lock()).Switch();}
	// We can't use the smp tag past here since it's mapped in a region which doesn't exist anymore.
	APIC::Enable();
	APIC::EnableTimer();
	APIC::LAPIC_HART_WAIT.store(false,Ordering::SeqCst);
	while !SCHEDULER_STARTED.load(Ordering::SeqCst) {core::hint::spin_loop();};
	crate::Scheduler::Scheduler::Start(CurrentHart());
}