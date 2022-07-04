use core::arch::asm;
use crate::arch::GDT::HARTS;
use crate::CurrentHart;
use crate::Memory::PageTable;
use crate::Process::{TaskState,TaskFloatState};

#[repr(C, align(8))]
#[derive(Debug)]
pub struct State {
    pub r15: u64,
    pub r14: u64,
    pub r13: u64,
    pub r12: u64,
    pub r11: u64,
    pub r10: u64,
    pub r9: u64,
    pub r8: u64,
    pub rbp: u64,
    pub rdi: u64, // syscall1
    pub rsi: u64, // syscall2
    pub rdx: u64, // syscall3
    pub rcx: u64,
    pub rbx: u64,
    pub rax: u64, // syscall0
    pub err_code: u64,
    pub rip: u64, // ip
    pub cs: u64,
    pub rflags: u64, // flags
    pub rsp: u64, // sp
    pub ss: u64,
}

impl State {
    pub fn new(idle_task: bool) -> Self {
        Self {
            rip: 0,
            cs: if idle_task {0x28} else {0x43},
            rflags: 0x200,
            rsp: if idle_task {unsafe {HARTS[CurrentHart() as usize].as_ref().unwrap().tss.privilege_stack_table[0].as_u64()}} else {0},
            ss: if idle_task {0x30} else {0x3B},
            err_code: 0,
            rax: 0,
            rbx: 0,
            rcx: 0,
            rdx: 0,
            rsi: 0,
            rdi: 0,
            rbp: 0,
            r8: 0,
            r9: 0,
            r10: 0,
            r11: 0,
            r12: 0,
            r13: 0,
            r14: 0,
            r15: 0,
        }
    }
    #[doc(hidden)]
    #[cold]
    #[naked]
    extern "C" fn _state_internal_enter(state: u64) {
        unsafe {
            asm!(
            "cli",
            "mov rsp, rdi",
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
            "add rsp, 8",
            "iretq",
            options(noreturn)
            );
        }
    }
}

impl TaskState for State {
    fn SetIP(&mut self, ip: usize) {
        self.rip = ip as u64;
    }
    fn GetIP(&self) -> usize {
        self.rip as usize
    }
    fn SetSP(&mut self, sp: usize) {
        self.rsp = sp as u64;
    }
    fn GetSP(&self) -> usize {
        self.rsp as usize
    }
    fn SetFlags(&mut self, flags: usize) {
        self.rflags = flags as u64;
    }
    fn GetFlags(&self) -> usize {
        self.rflags as usize
    }
    fn SetSC0(&mut self, val: usize) {self.rax = val as u64;}
    fn SetSC1(&mut self, val: usize) {self.rdi = val as u64;}
    fn SetSC2(&mut self, val: usize) {self.rsi = val as u64;}
    fn SetSC3(&mut self, val: usize) {self.rdx = val as u64;}
    fn GetSC0(&self) -> usize {self.rax as usize}
    fn GetSC1(&self) -> usize {self.rdi as usize}
    fn GetSC2(&self) -> usize {self.rsi as usize}
    fn GetSC3(&self) -> usize {self.rdx as usize}
    fn Save(&mut self, state: &State) {
        self.rip = state.rip;
        self.rflags = state.rflags;
        self.rsp = state.rsp;
        self.rax = state.rax;
        self.rbx = state.rbx;
        self.rcx = state.rcx;
        self.rdx = state.rdx;
        self.rsi = state.rsi;
        self.rdi = state.rdi;
        self.rbp = state.rbp;
        self.r8 = state.r8;
        self.r9 = state.r9;
        self.r10 = state.r10;
        self.r11 = state.r11;
        self.r12 = state.r12;
        self.r13 = state.r13;
        self.r14 = state.r14;
        self.r15 = state.r15;
    }
    fn Enter(&self) -> ! {
        State::_state_internal_enter(((self as &State) as *const State) as u64);
        unreachable!();
    }
    fn Exit(&self) {
        unsafe { crate::PageFrame::KernelPageTable.lock().Switch(); }
    }
}

#[repr(align(16))]
pub struct FloatState {
    state: [u8; 512],
}

impl FloatState {
    pub fn new() -> Self {
        Self {
            state: [0; 512],
        }
    }
}

impl TaskFloatState for FloatState {
    fn Save(&mut self) {
        unsafe { asm!("fxsave64 [rax]",in("rax")(&mut self.state as *mut u8)); }
    }
    fn Clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
    fn Restore(&self) {
        unsafe { asm!("fxrstor64 [rax]",in("rax")(&self.state as *const u8)); }
    }
}

pub fn SetupFPU() {
	let mut cr0 = x86_64::registers::control::Cr0::read();
	cr0.set(x86_64::registers::control::Cr0Flags::EMULATE_COPROCESSOR,false);
	cr0.set(x86_64::registers::control::Cr0Flags::MONITOR_COPROCESSOR,true);
    cr0.set(x86_64::registers::control::Cr0Flags::NUMERIC_ERROR,true);
    unsafe {x86_64::registers::control::Cr0::write(cr0);}
    let mut cr4 = x86_64::registers::control::Cr4::read();
    cr4.set(x86_64::registers::control::Cr4Flags::OSFXSR,true);
    cr4.set(x86_64::registers::control::Cr4Flags::OSXMMEXCPT_ENABLE,true);
    cr4.set(x86_64::registers::control::Cr4Flags::PAGE_GLOBAL,true);
    unsafe {x86_64::registers::control::Cr4::write(cr4);}
	unsafe { asm!("fninit"); }
}