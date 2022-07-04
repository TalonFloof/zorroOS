use core::arch::asm;
use core::sync::atomic::Ordering;
use x86_64::{PrivilegeLevel, VirtAddr};
use x86_64::instructions::port::PortWrite;
use x86_64::structures::idt::InterruptDescriptorTable;
use crate::arch::APIC;
use crate::arch::Task::State;
use crate::{CurrentHart, halt};
use crate::Scheduler::SCHEDULERS;
use log::error;
use spin::Mutex;

static mut kidt: InterruptDescriptorTable = InterruptDescriptorTable::new();

static ExceptionMessages: [&str; 32] = [
    "DivisionByZero",
    "Debug",
    "NonMaskableInterrupt",
    "Breakpoint",
    "DetectedOverflow",
    "OutOfBounds",
    "InvalidOpcode",
    "NoCoprocessor",
    "DoubleFault",
    "CoprocessorSegmentOverrun",
    "BadTss",
    "SegmentNotPresent",
    "StackFault",
    "GeneralProtectionFault",
    "PageFault",
    "UnknownInterrupt",
    "CoprocessorFault",
    "AlignmentCheck",
    "MachineCheck",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
];

pub static IRQ_HANDLERS: Mutex<[Option<fn()>; 0xE0]> = Mutex::new([None; 0xE0]);

#[no_mangle]
extern "C" fn x86Fault(
    index: u64,
    regs: &State,
) {
    if index == 0x02 {
        halt!();
        loop {};
    }
    let cr2 = x86_64::registers::control::Cr2::read().as_u64();
    if index == 0x0e {
        if (0x7f8000000000..0x800000000000).contains(&cr2) {
            let l = SCHEDULERS.lock();
            let pid = l.get(&(CurrentHart())).unwrap().current_proc_id.load(Ordering::SeqCst);
            drop(l);
            if crate::Process::PageFault(pid,cr2 as usize) {
                return;
            }
        }
    }
    if regs.cs == 0x43 && index != 0x08 {
        use crate::Memory::PageTable;
        unsafe { crate::PageFrame::KernelPageTable.lock().Switch(); }
        let l = SCHEDULERS.lock();
        let pid = l.get(&(CurrentHart())).unwrap().current_proc_id.load(Ordering::SeqCst);
        drop(l);
        error!("(hart 0x{}) Process #{} Exception {}", CurrentHart(), pid, ExceptionMessages[index as usize]);
        error!("{:?}", regs);
        if index == 0x0e {
            error!("CR2=0x{:016x}", cr2);
        }
        crate::Process::Process::SendSignal(pid,crate::Process::Signals::SIGSEGV);
        crate::Scheduler::Scheduler::Tick(CurrentHart(),regs);
    } else {
        if index != 14 && unsafe {crate::Console::QUIET} {
            // Page Dump
            let ptr = regs.rip & (!0xFFF);
            let location = regs.rip & 0xFFF;
            let mut lock = crate::Framebuffer::MainFramebuffer.lock();
            let width = (*lock).as_ref().unwrap().width;
            let height = (*lock).as_ref().unwrap().height;
            for i in 0..4096 {
                if location == i as u64 {
                    let color = unsafe {*((ptr as *const u8).offset(i))} as u32;
                    if color > 127 {
                        (*lock).as_mut().unwrap().DrawPixel((width-128)+(i as usize)%128,height-(i as usize/128),color<<16);
                    } else {
                        (*lock).as_mut().unwrap().DrawPixel((width-128)+(i as usize)%128,height-(i as usize/128),(color+128)<<8);
                    }
                } else {
                    let color = unsafe {*((ptr as *const u8).offset(i))} as u32;
                    (*lock).as_mut().unwrap().DrawPixel((width-128)+(i as usize)%128,height-(i as usize/128),(color<<16)|(color<<8)|color);
                }
            }
            drop(lock);
        }
        if index == 0xE {
            panic!("Unhandled AMD64 Fault: {}\nCR2=0x{:016x}\n{:?}", ExceptionMessages[index as usize], x86_64::registers::control::Cr2::read().as_u64(), regs);
        } else {
             panic!("Unhandled AMD64 Fault: {}\n{:?}", ExceptionMessages[index as usize], regs);
        }
    }
}

macro_rules! set_irq_handler {
    ($irq:expr, $priv:expr) => {{
        #[naked]
        extern "C" fn wrapper() {
            unsafe {
                asm!(
                    "cli",

                    "push rax",
                    "push rcx",
                    "push rdx",
                    "push rdi",
                    "push rsi",
                    "push r8",
                    "push r9",
                    "push r10",
                    "push r11",

                    concat!("mov rdi, ", $irq),
                    "cld",
                    "call x86IRQ",

                    "pop r11",
                    "pop r10",
                    "pop r9",
                    "pop r8",
                    "pop rsi",
                    "pop rdi",
                    "pop rdx",
                    "pop rcx",
                    "pop rax",

                    "iretq",
                    options(noreturn)
                );
            }
        }
        unsafe {
            let opt = kidt[$irq as usize].set_handler_addr(VirtAddr::new(wrapper as u64));
            opt.set_privilege_level($priv);
        }
    }};
    (exception_errcode $irq:expr, $priv:expr) => {{
        #[naked]
        extern "C" fn wrapper() {
            unsafe {
                asm!(
                    "cli",

                    "push rax",
                    "push rbx",
                    "push rcx",
                    "push rdx",
                    "push rsi",
                    "push rdi",
                    "push rbp",
                    "push r8",
                    "push r9",
                    "push r10",
                    "push r11",
                    "push r12",
                    "push r13",
                    "push r14",
                    "push r15",

                    concat!("mov rdi, ", $irq),
                    "mov rsi, rsp",
                    "cld",
                    "call x86Fault",
                    "add rsp, 8",

                    "pop r15",
                    "pop r14",
                    "pop r13",
                    "pop r12",
                    "pop r11",
                    "pop r10",
                    "pop r9",
                    "pop r8",
                    "pop rbp",
                    "pop rdi",
                    "pop rsi",
                    "pop rdx",
                    "pop rcx",
                    "pop rbx",
                    "pop rax",

                    "iretq",
                    options(noreturn)
                );
            }
        }
        unsafe {
            let opt;
            match $irq {
                0x08 => {
                    opt = kidt.double_fault.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x0a => {
                    opt = kidt.invalid_tss.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x0b => {
                    opt = kidt.segment_not_present.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x0c => {
                    opt = kidt.stack_segment_fault.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x0d => {
                    opt = kidt.general_protection_fault.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x0e => {
                    opt = kidt.page_fault.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x11 => {
                    opt = kidt.alignment_check.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x1d => {
                    opt = kidt.vmm_communication_exception.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                0x1e => {
                    opt = kidt.security_exception.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                _ => {
                    opt = kidt[$irq as usize].set_handler_addr(VirtAddr::new(wrapper as u64));
                }
            }
            opt.set_privilege_level($priv);
        }
    }};
    (exception_noerrcode $irq:expr, $priv:expr) => {{
        #[naked]
        extern "C" fn wrapper() {
            unsafe {
                asm!(
                    "cli",
                    "cld",
                    "push 0",

                    "push rax",
                    "push rbx",
                    "push rcx",
                    "push rdx",
                    "push rsi",
                    "push rdi",
                    "push rbp",
                    "push r8",
                    "push r9",
                    "push r10",
                    "push r11",
                    "push r12",
                    "push r13",
                    "push r14",
                    "push r15",

                    concat!("mov rdi, ", $irq),
                    "mov rsi, rsp",
                    "cld",
                    "call x86Fault",
                    "add rsp, 8",

                    "pop r15",
                    "pop r14",
                    "pop r13",
                    "pop r12",
                    "pop r11",
                    "pop r10",
                    "pop r9",
                    "pop r8",
                    "pop rbp",
                    "pop rdi",
                    "pop rsi",
                    "pop rdx",
                    "pop rcx",
                    "pop rbx",
                    "pop rax",

                    "iretq",
                    options(noreturn)
                );
            }
        }
        unsafe {
            let opt;
            match $irq {
                0x12 => {
                    opt = kidt.machine_check.set_handler_addr(VirtAddr::new(wrapper as u64));
                }
                _ => {
                    opt = kidt[$irq as usize].set_handler_addr(VirtAddr::new(wrapper as u64));
                }
            }
            opt.set_privilege_level($priv);
        }
    }};
    (thread_save $irq:expr, $priv:expr) => {{
        #[naked]
        extern "C" fn wrapper() {
            unsafe {
                asm!(
                    "cli",
                    "push 0",

                    "push rax",
                    "push rbx",
                    "push rcx",
                    "push rdx",
                    "push rsi",
                    "push rdi",
                    "push rbp",
                    "push r8",
                    "push r9",
                    "push r10",
                    "push r11",
                    "push r12",
                    "push r13",
                    "push r14",
                    "push r15",

                    "mov rdi, rsp",
                    "cld",
                    "call x86Timer",
                    "nop",
                    "ud2",
                    options(noreturn)
                );
            }
        }
        unsafe {
            let opt = kidt[$irq as usize].set_handler_addr(VirtAddr::new(wrapper as u64));
            opt.set_privilege_level($priv);
        }
    }};
}

#[no_mangle]
extern "C" fn x86IRQ(
    index: u64,
) {
    let lock = IRQ_HANDLERS.lock();
    if lock[(index as usize)-0x20].is_some() {
        (lock[index as usize-0x20].unwrap())();
    }
    drop(lock);
    APIC::Write(APIC::LOCAL_APIC_EOI,0);
}

#[no_mangle]
extern "C" fn x86Timer(
    cr: &mut State
) -> ! {
    APIC::Write(APIC::LOCAL_APIC_EOI,0);
    crate::Scheduler::Scheduler::Tick(CurrentHart(), cr);
    panic!("You'll never see this message, isn't that weird?");
}

pub unsafe fn Setup() {
    IDTSetup();
    kidt.load();
    u8::write_to_port(0x29,0xff);
    u8::write_to_port(0x21,0xff);
}
#[doc(hidden)]
fn IDTSetup() {
    set_irq_handler!(exception_noerrcode 0x00,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x01,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x02,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x03,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x04,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x05,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x06,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x07,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x08,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x0a,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x0b,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x0c,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x0d,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x0e,PrivilegeLevel::Ring0);

    set_irq_handler!(exception_noerrcode 0x10,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x11,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x12,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x13,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_noerrcode 0x14,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x1d,PrivilegeLevel::Ring0);
    set_irq_handler!(exception_errcode 0x1e,PrivilegeLevel::Ring0);

    set_irq_handler!(thread_save 0x20,PrivilegeLevel::Ring0);
    set_irq_handler!(0x21,PrivilegeLevel::Ring0);
    set_irq_handler!(0x22,PrivilegeLevel::Ring0);
    set_irq_handler!(0x23,PrivilegeLevel::Ring0);
    set_irq_handler!(0x24,PrivilegeLevel::Ring0);
    set_irq_handler!(0x25,PrivilegeLevel::Ring0);
    set_irq_handler!(0x26,PrivilegeLevel::Ring0);
    set_irq_handler!(0x27,PrivilegeLevel::Ring0);
    set_irq_handler!(0x28,PrivilegeLevel::Ring0);
    set_irq_handler!(0x29,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x2f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x30,PrivilegeLevel::Ring0);
    set_irq_handler!(0x31,PrivilegeLevel::Ring0);
    set_irq_handler!(0x32,PrivilegeLevel::Ring0);
    set_irq_handler!(0x33,PrivilegeLevel::Ring0);
    set_irq_handler!(0x34,PrivilegeLevel::Ring0);
    set_irq_handler!(0x35,PrivilegeLevel::Ring0);
    set_irq_handler!(0x36,PrivilegeLevel::Ring0);
    set_irq_handler!(0x37,PrivilegeLevel::Ring0);
    set_irq_handler!(0x38,PrivilegeLevel::Ring0);
    set_irq_handler!(0x39,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x3f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x40,PrivilegeLevel::Ring0);
    set_irq_handler!(0x41,PrivilegeLevel::Ring0);
    set_irq_handler!(0x42,PrivilegeLevel::Ring0);
    set_irq_handler!(0x43,PrivilegeLevel::Ring0);
    set_irq_handler!(0x44,PrivilegeLevel::Ring0);
    set_irq_handler!(0x45,PrivilegeLevel::Ring0);
    set_irq_handler!(0x46,PrivilegeLevel::Ring0);
    set_irq_handler!(0x47,PrivilegeLevel::Ring0);
    set_irq_handler!(0x48,PrivilegeLevel::Ring0);
    set_irq_handler!(0x49,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x4f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x50,PrivilegeLevel::Ring0);
    set_irq_handler!(0x51,PrivilegeLevel::Ring0);
    set_irq_handler!(0x52,PrivilegeLevel::Ring0);
    set_irq_handler!(0x53,PrivilegeLevel::Ring0);
    set_irq_handler!(0x54,PrivilegeLevel::Ring0);
    set_irq_handler!(0x55,PrivilegeLevel::Ring0);
    set_irq_handler!(0x56,PrivilegeLevel::Ring0);
    set_irq_handler!(0x57,PrivilegeLevel::Ring0);
    set_irq_handler!(0x58,PrivilegeLevel::Ring0);
    set_irq_handler!(0x59,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x5f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x60,PrivilegeLevel::Ring0);
    set_irq_handler!(0x61,PrivilegeLevel::Ring0);
    set_irq_handler!(0x62,PrivilegeLevel::Ring0);
    set_irq_handler!(0x63,PrivilegeLevel::Ring0);
    set_irq_handler!(0x64,PrivilegeLevel::Ring0);
    set_irq_handler!(0x65,PrivilegeLevel::Ring0);
    set_irq_handler!(0x66,PrivilegeLevel::Ring0);
    set_irq_handler!(0x67,PrivilegeLevel::Ring0);
    set_irq_handler!(0x68,PrivilegeLevel::Ring0);
    set_irq_handler!(0x69,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x6f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x70,PrivilegeLevel::Ring0);
    set_irq_handler!(0x71,PrivilegeLevel::Ring0);
    set_irq_handler!(0x72,PrivilegeLevel::Ring0);
    set_irq_handler!(0x73,PrivilegeLevel::Ring0);
    set_irq_handler!(0x74,PrivilegeLevel::Ring0);
    set_irq_handler!(0x75,PrivilegeLevel::Ring0);
    set_irq_handler!(0x76,PrivilegeLevel::Ring0);
    set_irq_handler!(0x77,PrivilegeLevel::Ring0);
    set_irq_handler!(0x78,PrivilegeLevel::Ring0);
    set_irq_handler!(0x79,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x7f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x80,PrivilegeLevel::Ring0);
    set_irq_handler!(0x81,PrivilegeLevel::Ring0);
    set_irq_handler!(0x82,PrivilegeLevel::Ring0);
    set_irq_handler!(0x83,PrivilegeLevel::Ring0);
    set_irq_handler!(0x84,PrivilegeLevel::Ring0);
    set_irq_handler!(0x85,PrivilegeLevel::Ring0);
    set_irq_handler!(0x86,PrivilegeLevel::Ring0);
    set_irq_handler!(0x87,PrivilegeLevel::Ring0);
    set_irq_handler!(0x88,PrivilegeLevel::Ring0);
    set_irq_handler!(0x89,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x8f,PrivilegeLevel::Ring0);

    set_irq_handler!(0x90,PrivilegeLevel::Ring0);
    set_irq_handler!(0x91,PrivilegeLevel::Ring0);
    set_irq_handler!(0x92,PrivilegeLevel::Ring0);
    set_irq_handler!(0x93,PrivilegeLevel::Ring0);
    set_irq_handler!(0x94,PrivilegeLevel::Ring0);
    set_irq_handler!(0x95,PrivilegeLevel::Ring0);
    set_irq_handler!(0x96,PrivilegeLevel::Ring0);
    set_irq_handler!(0x97,PrivilegeLevel::Ring0);
    set_irq_handler!(0x98,PrivilegeLevel::Ring0);
    set_irq_handler!(0x99,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9a,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9b,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9c,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9d,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9e,PrivilegeLevel::Ring0);
    set_irq_handler!(0x9f,PrivilegeLevel::Ring0);

    set_irq_handler!(0xa0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xa9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xaa,PrivilegeLevel::Ring0);
    set_irq_handler!(0xab,PrivilegeLevel::Ring0);
    set_irq_handler!(0xac,PrivilegeLevel::Ring0);
    set_irq_handler!(0xad,PrivilegeLevel::Ring0);
    set_irq_handler!(0xae,PrivilegeLevel::Ring0);
    set_irq_handler!(0xaf,PrivilegeLevel::Ring0);

    set_irq_handler!(0xb0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xb9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xba,PrivilegeLevel::Ring0);
    set_irq_handler!(0xbb,PrivilegeLevel::Ring0);
    set_irq_handler!(0xbc,PrivilegeLevel::Ring0);
    set_irq_handler!(0xbd,PrivilegeLevel::Ring0);
    set_irq_handler!(0xbe,PrivilegeLevel::Ring0);
    set_irq_handler!(0xbf,PrivilegeLevel::Ring0);

    set_irq_handler!(0xc0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xc9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xca,PrivilegeLevel::Ring0);
    set_irq_handler!(0xcb,PrivilegeLevel::Ring0);
    set_irq_handler!(0xcc,PrivilegeLevel::Ring0);
    set_irq_handler!(0xcd,PrivilegeLevel::Ring0);
    set_irq_handler!(0xce,PrivilegeLevel::Ring0);
    set_irq_handler!(0xcf,PrivilegeLevel::Ring0);

    set_irq_handler!(0xd0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xd9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xda,PrivilegeLevel::Ring0);
    set_irq_handler!(0xdb,PrivilegeLevel::Ring0);
    set_irq_handler!(0xdc,PrivilegeLevel::Ring0);
    set_irq_handler!(0xdd,PrivilegeLevel::Ring0);
    set_irq_handler!(0xde,PrivilegeLevel::Ring0);
    set_irq_handler!(0xdf,PrivilegeLevel::Ring0);

    set_irq_handler!(0xe0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xe9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xea,PrivilegeLevel::Ring0);
    set_irq_handler!(0xeb,PrivilegeLevel::Ring0);
    set_irq_handler!(0xec,PrivilegeLevel::Ring0);
    set_irq_handler!(0xed,PrivilegeLevel::Ring0);
    set_irq_handler!(0xee,PrivilegeLevel::Ring0);
    set_irq_handler!(0xef,PrivilegeLevel::Ring0);

    set_irq_handler!(0xf0,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf1,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf2,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf3,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf4,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf5,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf6,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf7,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf8,PrivilegeLevel::Ring0);
    set_irq_handler!(0xf9,PrivilegeLevel::Ring0);
    set_irq_handler!(0xfa,PrivilegeLevel::Ring0);
    set_irq_handler!(0xfb,PrivilegeLevel::Ring0);
    set_irq_handler!(0xfc,PrivilegeLevel::Ring0);
    set_irq_handler!(0xfd,PrivilegeLevel::Ring0);
    set_irq_handler!(0xfe,PrivilegeLevel::Ring0);
}