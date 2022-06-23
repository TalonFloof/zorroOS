use alloc::collections::BTreeMap;
use core::sync::atomic::{AtomicI32, AtomicU32, Ordering};
use spin::mutex::Mutex;
use crate::arch::Task::{State,FloatState};
use crate::CurrentHart;
use crate::Memory::PageTable;
use crate::arch::Memory::PageTableImpl;
use crate::Scheduler::SCHEDULERS;
use alloc::string::String;
use alloc::sync::Arc;
use crate::FS::VFS::FileDescriptor;
use alloc::vec::Vec;

pub static PROCESSES: Mutex<BTreeMap<i32,Process>> = Mutex::new(BTreeMap::new());
pub static NEXTPROCESS: AtomicI32 = AtomicI32::new(1);

pub mod Signals {
    pub const SIGHUP: u8 =  0x01; // Terminate
    pub const SIGINT: u8 =  0x02; // Terminate
    pub const SIGQUIT: u8 = 0x03; // Abort
    pub const SIGILL: u8 =  0x04; // Abort
    pub const SIGTRAP: u8 = 0x05; // Abort
    pub const SIGABRT: u8 = 0x06; // Abort (What did you think it would do?)
    pub const SIGBUS: u8 =  0x07; // Abort
    pub const SIGFPE: u8 =  0x08; // Abort
    pub const SIGKILL: u8 = 0x09; // Terminate (Cannot be caught or ignored)
    pub const SIGUSR1: u8 = 0x0a; // Terminate
    pub const SIGSEGV: u8 = 0x0b; // Abort
    pub const SIGUSR2: u8 = 0x0c; // Terminate
    pub const SIGPIPE: u8 = 0x0d; // Terminate
    pub const SIGALRM: u8 = 0x0e; // Terminate
    pub const SIGTERM: u8 = 0x0f; // Terminate (Do I really need to explain why...)
    pub const SIGCHLD: u8 = 0x11; // Ignored
    pub const SIGCONT: u8 = 0x12; // Continue
    pub const SIGSTOP: u8 = 0x13; // Stop (Cannot be caught or ignored)
    pub const SIGTSTP: u8 = 0x14; // Stop (Sent by Terminal)
    pub const SIGTTIN: u8 = 0x15; // Stop
    pub const SIGTTOU: u8 = 0x16; // Stop
    pub const SIGURG: u8 =  0x17; // Ignored
}

pub enum ProcessStatus {
    NEW,
    RUNNABLE,
    STOPPED,
    FORCEKILL(bool), // This is a special status given to child processes after the parent gets cleaned up to prevent orphan processes from being created.
    SIGNAL(usize,usize),
    FINISHING(isize),
    FINISHED(isize),
    SLEEPING(i64),
}

pub trait TaskState: Send + Sync {
    fn SetIP(&mut self, ip: usize);
    fn GetIP(&self) -> usize;
    fn SetSP(&mut self, sp: usize);
    fn GetSP(&self) -> usize;
    fn SetFlags(&mut self, flags: usize);
    fn GetFlags(&self) -> usize;
    fn SetSC0(&mut self, val: usize);
    fn SetSC1(&mut self, val: usize);
    fn SetSC2(&mut self, val: usize);
    fn SetSC3(&mut self, val: usize);
    fn GetSC0(&self) -> usize;
    fn GetSC1(&self) -> usize;
    fn GetSC2(&self) -> usize;
    fn GetSC3(&self) -> usize;
    fn Save(&mut self, state: &State);
    fn Enter(&self) -> !;
    fn Exit(&self);
}

pub trait TaskFloatState: Send + Sync {
    fn Save(&mut self);
    fn Clone(&self) -> Self;
    fn Restore(&self);
}

pub struct Process {
    pub id: i32,
    pub parent_id: i32,
    pub children: Vec<i32>,

    pub task_state: State,
    pub sig_state: State,
    pub task_fpstate: FloatState,

    pub hart: AtomicU32,
    pub name: String,

    pub ruid: u32,
    pub rgid: u32,
    pub euid: u32,
    pub egid: u32,
    pub umask: i32,
    pub pgid: i32,

    pub pagetable: Arc<PageTableImpl>,

    pub cwd: String,
    pub status: ProcessStatus,

    pub fds: BTreeMap<i64, FileDescriptor>,

    pub heap_base: usize,
    pub heap_length: Arc<Mutex<usize>>,

    pub signals: [usize; 25],
}

pub const USERSPACE_STACK_SIZE: u64 = 0x4000;

impl Process {
    pub fn new(name: String, parent: i32) -> Self {
        let state = State::new(false);
        Self {
            id: i32::MIN,
            parent_id: parent,
            children: Vec::new(),

            task_state: state,
            sig_state: State::new(false),
            task_fpstate: FloatState::new(),

            hart: AtomicU32::new(u32::MAX),
            name,

            ruid: 0,
            rgid: 0,
            euid: 0,
            egid: 0,
            umask: 0o022,
            pgid: 0,
            
            pagetable: Arc::new(PageTableImpl::new()),

            cwd: String::from("/"),
            status: ProcessStatus::NEW,

            fds: BTreeMap::new(),

            heap_base: 0,
            heap_length: Arc::new(Mutex::new(0)),

            signals: [0; 25],
        }
    }
    pub fn ContextSwitch(&self) -> ! {
        unsafe {self.pagetable.Switch();}
        self.task_state.Enter()
    }
    //////////////////////////////////////////////////////////////
    pub fn AddProcess(mut proc: Process) -> i32 {
        let mut plock = PROCESSES.lock();
        let id = NEXTPROCESS.fetch_add(1,Ordering::SeqCst);
        proc.id = id;
        if let Some(parent) = plock.get_mut(&proc.parent_id) {
            parent.children.push(id);
        }
        plock.insert(id,proc);
        drop(plock);
        return id;
    }
    //////////////////////////////////////////////////////////////
    pub fn CleanupProcess(pid: i32) {
        let mut lock = PROCESSES.lock();
        let proc = lock.get_mut(&pid).unwrap();
        let slock = SCHEDULERS.lock();
        if slock.get(&CurrentHart()).unwrap().current_proc_id.load(Ordering::SeqCst) == pid {
            proc.task_state.Exit();
        }
        let mut pqlock = slock.get(&proc.hart.load(Ordering::SeqCst)).unwrap().process_queue.lock();
        if pqlock.contains(&pid) {
            pqlock.retain(|&x| x != pid);
        }
        drop(pqlock);
        drop(slock);
        drop(lock);
    }
    pub fn SendSignal(pid: i32, sig: u8) -> isize {
        let mut lock = PROCESSES.lock();
        match lock.get_mut(&pid) {
            Some(proc) => {
                let sighandle = proc.signals[sig as usize];
                if matches!(proc.status,ProcessStatus::SIGNAL(_,_)) || proc.sig_state.GetIP() != 0 {
                    drop(lock);
                    return -crate::Syscall::Errors::EAGAIN as isize;
                } else if !matches!(proc.status,ProcessStatus::RUNNABLE) && !matches!(proc.status,ProcessStatus::SLEEPING(_)) {
                    drop(lock);
                    return -crate::Syscall::Errors::ESRCH as isize;
                }
                if sighandle == 0 || sig == Signals::SIGKILL || sig == Signals::SIGSTOP {
                    if sig >= 0x1 && sig <= 0xf {
                        proc.status = ProcessStatus::FINISHING(-(sig as isize));
                        let children = proc.children.clone();
                        drop(lock);
                        let mut lock = PROCESSES.lock();
                        for i in children.iter() {
                            if let Some(child) = lock.get_mut(&i) {
                                child.status = ProcessStatus::FORCEKILL(false);
                            }
                        }
                        drop(children);
                        drop(lock);
                        return 0;
                    } else if sig >= 0x13 && sig <= 0x16 {
                        proc.status = ProcessStatus::STOPPED;
                    }
                    drop(lock);
                    return 0;
                } else {
                    proc.sig_state.Save(&proc.task_state);
                    proc.status = ProcessStatus::SIGNAL(sighandle,sig as usize);
                    drop(lock);
                    return 0;
                }
            }
            _ => {
                drop(lock);
                return -crate::Syscall::Errors::ESRCH as isize;
            }
        }

    }
    pub fn StartProcess(pid: i32, ip: usize, sp: usize) {
        let mut lock = PROCESSES.lock();
        let proc = lock.get_mut(&pid).unwrap();
        match proc.status {
            ProcessStatus::NEW => {
                proc.task_state.SetIP(ip);
                proc.task_state.SetSP(sp);
                proc.status = ProcessStatus::RUNNABLE;
                let mut slock = SCHEDULERS.lock();
                if slock.len() > 0 {
                    let mut smallest: (u32, usize) = (u32::MAX,usize::MAX);
                    for i in slock.iter() {
                        let tqlock = i.1.process_queue.lock();
                        if tqlock.len() < smallest.1 {
                            smallest = (*i.0,tqlock.len());
                        }
                        drop(tqlock);
                    }
                    let mut pqlock = slock.get_mut(&smallest.0).unwrap().process_queue.lock();
                    pqlock.push_front(pid);
                    drop(pqlock);
                }
                drop(slock);
            },
            _ => {}
        }
        drop(lock);
    }
    pub fn Fork(&mut self) -> Self {
        let mut task_state = State::new(false);
        task_state.Save(&self.task_state);
        task_state.SetSC0(0);
        let mut sig_state = State::new(false);
        sig_state.Save(&self.sig_state);
        let mut fds = BTreeMap::new();
        for (i,j) in self.fds.iter() {
            fds.insert(*i,j.clone());
        }
        Self {
            id: i32::MIN,
            parent_id: self.id,
            children: Vec::new(),

            task_state,
            sig_state,
            task_fpstate: self.task_fpstate.Clone(),

            hart: AtomicU32::new(u32::MAX),
            name: self.name.clone(),

            ruid: self.ruid,
            rgid: self.rgid,
            euid: self.euid,
            egid: self.egid,
            umask: self.umask,
            pgid: self.pgid,

            pagetable: self.pagetable.Clone(true),

            cwd: self.cwd.clone(),
            status: ProcessStatus::NEW,

            fds,

            heap_base: self.heap_base,
            heap_length: self.heap_length.clone(),

            signals: self.signals.clone(),
        }
    }
}