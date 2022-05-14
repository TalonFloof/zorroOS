use core::arch::asm;
use core::sync::atomic::Ordering;
use x86_64::{PrivilegeLevel, set_general_handler, VirtAddr};
use x86_64::instructions::port::PortWrite;
use x86_64::structures::idt::{InterruptDescriptorTable, InterruptStackFrame};
use crate::arch::APIC;
use crate::arch::Task::State;
use crate::{CurrentHart, halt};
use crate::Scheduler::{Scheduler, SCHEDULER_STARTED, SCHEDULERS};
use crate::print;
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

fn x86Fault(
    stack_frame: InterruptStackFrame,
    index: u8,
    err_code: Option<u64>
) {
    if index == 0x02 {
        x86_64::instructions::interrupts::disable();
        halt!();
        loop {};
    }
    if stack_frame.code_segment == 0x23 && index != 0x08 {
        let l = SCHEDULERS.lock();
        let ptr = l.get(&(CurrentHart())).unwrap() as *const Scheduler;
        drop(l);
        let pid = unsafe{(&*ptr).current_proc_id.load(Ordering::SeqCst)};
        print!("\x1b[31m(hart 0x{}) Process #{} Exception {}\n{:?}\n", CurrentHart(), pid, ExceptionMessages[index as usize], stack_frame);
        if let None = err_code {} else {
            print!("AMD64_ERR_CODE=0x{:x}\n", err_code.unwrap());
        }
        if index == 0x0e {
            print!("CR2={:016x}\n", x86_64::registers::control::Cr2::read().as_u64());
        }
        print!("\x1b[0m");
        crate::Process::Process::DestroyProcess(pid);
        unsafe {(&*ptr).NextContext();}
    } else {
        if let None = err_code {
            panic!("Unhandled AMD64 Fault: {}\n{:?}", ExceptionMessages[index as usize], stack_frame);
        } else {
            if index == 0xE {
                panic!("Unhandled AMD64 Fault: {} AMD64_ERR_CODE=0x{:x}\nCR2=0x{:016x}\n{:?}", ExceptionMessages[index as usize], err_code.unwrap(), x86_64::registers::control::Cr2::read().as_u64(), stack_frame);
            } else {
                panic!("Unhandled AMD64 Fault: {} AMD64_ERR_CODE=0x{:x}\n{:?}", ExceptionMessages[index as usize], err_code.unwrap(), stack_frame);
            }
        }
    }
}

macro_rules! set_irq_handler {
    ($handle: ident, $irq:expr, $priv:expr) => {{
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
                    "mov rdi, rsp",
                    concat!("mov rsi, ", $irq),
                    "call {0}",
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
                    "sti",
                    "iretq",
                    sym $handle,
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

extern "C" fn x86IRQ(
    cr: &mut State,
    index: u64,
) {
    APIC::Write(APIC::LOCAL_APIC_EOI,0);
    if index == 0x20 {
        if SCHEDULER_STARTED.load(Ordering::Relaxed) {
            crate::Scheduler::Scheduler::Tick(CurrentHart(), cr);
        }
    } else {
        let lock = IRQ_HANDLERS.lock();
        if lock[(index as usize)-0x20].is_some() {
            (lock[index as usize-0x20].unwrap())();
        }
        drop(lock);
    }
}

/* 
This bit of code actually tricks the Rust compiler to allow me
to pass a mutable static into the set_general_handler! macro.
*/
pub unsafe fn Setup() {
    IDTSetup(&mut kidt);
    kidt.load();
    u8::write_to_port(0x29,0xff);
    u8::write_to_port(0x21,0xff);
    //x86_64::instructions::interrupts::enable();
}
#[doc(hidden)]
fn IDTSetup(inttab: &mut InterruptDescriptorTable) {
    set_general_handler!(inttab, x86Fault, 0x00..0x1f);
    set_irq_handler!(x86IRQ,0x20,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x21,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x22,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x23,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x24,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x25,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x26,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x27,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x28,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x29,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x2f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x30,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x31,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x32,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x33,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x34,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x35,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x36,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x37,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x38,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x39,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x3f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x40,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x41,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x42,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x43,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x44,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x45,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x46,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x47,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x48,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x49,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x4f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x50,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x51,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x52,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x53,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x54,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x55,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x56,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x57,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x58,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x59,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x5f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x60,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x61,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x62,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x63,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x64,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x65,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x66,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x67,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x68,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x69,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x6f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x70,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x71,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x72,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x73,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x74,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x75,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x76,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x77,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x78,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x79,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x7f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x80,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x81,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x82,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x83,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x84,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x85,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x86,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x87,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x88,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x89,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x8f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0x90,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x91,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x92,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x93,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x94,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x95,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x96,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x97,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x98,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x99,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9a,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9b,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9c,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9d,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9e,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0x9f,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xa0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xa9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xaa,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xab,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xac,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xad,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xae,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xaf,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xb0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xb9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xba,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xbb,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xbc,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xbd,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xbe,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xbf,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xc0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xc9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xca,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xcb,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xcc,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xcd,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xce,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xcf,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xd0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xd9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xda,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xdb,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xdc,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xdd,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xde,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xdf,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xe0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xe9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xea,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xeb,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xec,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xed,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xee,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xef,PrivilegeLevel::Ring0);

    set_irq_handler!(x86IRQ,0xf0,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf1,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf2,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf3,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf4,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf5,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf6,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf7,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf8,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xf9,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xfa,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xfb,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xfc,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xfd,PrivilegeLevel::Ring0);
    set_irq_handler!(x86IRQ,0xfe,PrivilegeLevel::Ring0);
}