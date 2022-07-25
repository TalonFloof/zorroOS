#[macro_use]
pub mod UART;

pub mod Memory;
pub mod IDT;
pub mod GDT;
pub mod APIC;
pub mod ACPI;
pub mod Timer;
pub mod Task;
pub mod Syscall;

extern crate limine;
extern crate x86_64;

use core::arch::asm;
use core::sync::atomic::Ordering;
use limine::*;
use crate::Memory::PageTable;
use crate::print_startup_message;
use crate::Scheduler::SCHEDULER_STARTED;
use alloc::string::String;
use alloc::vec::Vec;

pub const PHYSMEM_BEGIN: u64 = 0xFFFF_8000_0000_0000;

#[macro_export]
macro_rules! halt {
	() => {
		unsafe { core::arch::asm!("hlt"); }
	}
}

#[inline(always)]
pub fn CurrentHart() -> u32 {
	unsafe {*((x86_64::registers::model_specific::KernelGsBase::read().as_ptr() as *const u64).offset(2)) as u32}
}
#[macro_export]
macro_rules! halt_other_harts {
	() => {
		use crate::Memory::PageTable;
		x86_64::instructions::interrupts::disable();
		//unsafe {crate::Console::WRITER.force_unlock();}
		if crate::PageFrame::TotalMem.load(core::sync::atomic::Ordering::SeqCst) > 0 { unsafe { crate::PageFrame::KernelPageTable.lock().Switch(); } }
		if let Some(flags) = crate::CommandLine::FLAGS.get() {
			if matches!(flags.get("--nosmp"),None) {
				if crate::arch::APIC::LAPIC_READY.load(core::sync::atomic::Ordering::SeqCst) {
					crate::arch::APIC::SendIPI(crate::arch::CurrentHart() as u8,crate::arch::APIC::ICR_DSH_OTHER,crate::arch::APIC::ICR_MESSAGE_TYPE_NMI,0);
				}
			}
		}
	}
}

// LIMINE BOOT REQUESTS
pub static BOOTLOADER: LimineBootInfoRequest = LimineBootInfoRequest::new(0);
pub static HIGHER_HALF_DIRECT_MAPPINGS: LimineHhdmRequest = LimineHhdmRequest::new(0);
pub static FRAMEBUFFER: LimineFramebufferRequest = LimineFramebufferRequest::new(0);
pub static MMAP: LimineMmapRequest = LimineMmapRequest::new(0);
pub static RSDP: LimineRsdpRequest = LimineRsdpRequest::new(0);
pub static SMP: LimineSmpRequest = LimineSmpRequest::new(0).flags(0);
pub static TIMESTAMP: LimineBootTimeRequest = LimineBootTimeRequest::new(0);
pub static STACK: LimineStackSizeRequest = LimineStackSizeRequest::new(0).stack_size(65536); // 64 KiB
pub static KERNEL_FILE: LimineKernelFileRequest = LimineKernelFileRequest::new(0);
pub static MODULES: LimineModuleRequest = LimineModuleRequest::new(0);
pub static TERMINAL: LimineTerminalRequest = LimineTerminalRequest::new(0);

#[naked]
#[no_mangle]
extern "C" fn _start_entry() {
	unsafe {
		asm!(
			"cli",
			"mov rdi, rsp",
			"add rdi, 8",
			"call _start",
			"nop",
			"2:",
			"hlt",
			"jmp 2b",
			options(noreturn)
		)
	}
}

#[no_mangle]
extern "C" fn _start(stack_top: u64) {
    UART::Setup();
	print_startup_message!();
	crate::Allocator::Setup();
	GDT::Setup(stack_top);
	unsafe { IDT::Setup(); }
	Syscall::Initialize();
	Task::SetupFPU();
	Memory::AnalyzeMMAP();
	if unsafe {KERNEL_FILE.get_response().get()}.is_some() {
		let cmdstr = String::from(unsafe {KERNEL_FILE.get_response().get().unwrap().kernel_file.get()}.unwrap().cmdline.to_string().unwrap());
		if cmdstr.len() == 0 {
			log::warn!("Kernel Command Line is empty!");
		} else {
			log::info!("Kernel Command Line: \"{}\"", cmdstr.as_str());
		}
		crate::CommandLine::Parse(cmdstr);
	} else {
		log::error!("Bootloader didn't specify Kernel Command Line!");
	}
	if unsafe {FRAMEBUFFER.get_response().get()}.is_some() {
		let fb_tag = &unsafe {FRAMEBUFFER.get_response().get()}.unwrap().framebuffers().unwrap()[0];
		crate::Framebuffer::Init(fb_tag.address.as_ptr().unwrap() as *mut u32,fb_tag.width as usize,fb_tag.height as usize,fb_tag.pitch as usize,fb_tag.bpp as usize);
	}
	unsafe {crate::UNIX_EPOCH = TIMESTAMP.get_response().get().expect("The Fox Kernel requires that the Limine compatible bootloader that you are using contains a UNIX Epoch Timestamp.").boot_time as u64};
	ACPI::AnalyzeRSDP();
	if !crate::CommandLine::FLAGS.get().unwrap().contains("--nosmp") {
		APIC::EnableHarts();
	} else {
		log::warn!("Symmetric Multiprocessing was disabled by bootloader!");
	}
	if let Some(mods) = unsafe {MODULES.get_response().get()} {
		let mut mod_list: Vec<(String,&[u8])> = Vec::new();
		for i in mods.modules().unwrap().iter() {
			unsafe {mod_list.push((String::from(i.cmdline.to_string().unwrap()),core::slice::from_raw_parts(i.base.as_ptr().unwrap(), i.length as usize)));}
		}
		crate::main(mod_list);
	} else {
		log::warn!("Limine compatible bootloader doesn't support modules!");
		crate::main(Vec::new());
	}
}

#[naked]
extern "C" fn _Hart_start_entry() {
	unsafe {
		asm!(
			"cli",
			"mov rsi, rsp",
			"add rsi, 8",
			"call _Hart_start",
			"nop",
			"2:",
			"hlt",
			"jmp 2b",
			options(noreturn)
		)
	}
}

#[no_mangle]
extern "C" fn _Hart_start(smp: &'static LimineSmpInfo, stack_top: u64) -> ! {
	unsafe {GDT::HARTS[smp.lapic_id as usize].as_mut().unwrap().init(stack_top);}
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