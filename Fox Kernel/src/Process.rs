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
use alloc::boxed::Box;

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

    pub memory_segments: Arc<Mutex<Vec<(usize,usize,String,u8)>>>,

    pub signals: [usize; 25],

    pub supgroups: Vec<u32>,
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

            memory_segments: Arc::new(Mutex::new(Vec::new())),

            signals: [0; 25],

            supgroups: Vec::new(),
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
                    proc.hart.store(smallest.0,Ordering::SeqCst);
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
            j.inode.Open(usize::MAX);
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

            memory_segments: self.memory_segments.clone(),

            signals: self.signals.clone(),

            supgroups: self.supgroups.clone(),
        }
    }
    pub fn Exec(pid: i32, path: &str, argv: Option<&[Box<[u8]>]>, envp: Option<&[Box<[u8]>]>) -> usize {
        use crate::Scheduler::Scheduler;
        use crate::ELF::LoadELFFromPath;
        let mut plock = PROCESSES.lock();
        let proc = (&mut plock).get_mut(&pid).unwrap();
        /*let argv_raw: *const *const c_char = regs.GetSC2() as *const *const c_char;
        let envp_raw: *const *const c_char = regs.GetSC3() as *const *const c_char;
        let mut argv: Vec<CString> = Vec::new();
        let mut envp: Vec<CString> = Vec::new();
        let mut total_size = 0;
        unsafe {
            for i in 0..256 { // There is no reason for us to go beyond 255 arguments
                if argv_raw.offset(i).read() as usize == 0 {
                    break;
                }
                let arg = CString::from_raw(argv_raw.offset(i).read() as *mut c_char).clone();
                total_size += arg.as_bytes_with_nul().len();
                argv.push(arg);
            }
            if regs.GetSC3() != 0 {
                for i in 0..256 {
                    if envp_raw.offset(i).read() as usize == 0 {
                        break;
                    }
                    let arg = CString::from_raw(envp_raw.offset(i).read() as *mut c_char).clone();
                    total_size += arg.as_bytes_with_nul().len();
                    envp.push(arg);
                }
            }
        }
        let argv_ptr_slice: &mut [usize] = unsafe {core::slice::from_raw_parts_mut(Allocate(0x1000).unwrap() as *mut usize,256)};
        let envp_ptr_slice: &mut [usize] = unsafe {core::slice::from_raw_parts_mut(Allocate(0x1000).unwrap() as *mut usize,256)};
        let argv_str_slice: &mut [u8] = unsafe {core::slice::from_raw_parts_mut(Allocate((total_size as u64).div_ceil(0x1000)*0x1000).unwrap() as *mut u8,total_size)};
        let mut cur_pos = 0;
        for (i,j) in argv.iter().enumerate() {
            argv_str_slice[cur_pos..cur_pos+j.as_bytes_with_nul().len()].copy_from_slice(j.as_bytes_with_nul());
            argv_ptr_slice[i] = 0x3000+cur_pos;
            cur_pos += j.as_bytes_with_nul().len();
        }
        for (i,j) in envp.iter().enumerate() {
            argv_str_slice[cur_pos..cur_pos+j.as_bytes_with_nul().len()].copy_from_slice(j.as_bytes_with_nul());
            envp_ptr_slice[i] = 0x3000+cur_pos;
            cur_pos += j.as_bytes_with_nul().len();
        }*/
        let mut pt = PageTableImpl::new();
        let mut segments: Vec<(usize,usize,String,u8)> = Vec::new();
        match LoadELFFromPath(crate::FS::VFS::GetAbsPath(path,proc.cwd.as_str()),&mut pt,&mut segments) {
            Ok(val) => {
                /*crate::Memory::MapPages(&mut pt,0x1000,argv_ptr_slice.as_ptr() as usize - crate::arch::PHYSMEM_BEGIN as usize,0x1000,false,false);
                crate::Memory::MapPages(&mut pt,0x2000,envp_ptr_slice.as_ptr() as usize - crate::arch::PHYSMEM_BEGIN as usize,0x1000,false,false);
                crate::Memory::MapPages(&mut pt,0x3000,argv_str_slice.as_ptr() as usize - crate::arch::PHYSMEM_BEGIN as usize,argv_str_slice.len().div_ceil(0x1000)*0x1000,false,false);*/
                proc.task_state.Exit();
                proc.memory_segments = Arc::new(Mutex::new(segments));
                proc.pagetable = Arc::new(pt); // Old pagetable will be dropped if all references are gone
                unsafe {proc.pagetable.Switch();}
                proc.task_state.SetIP(val);
                unsafe {
                    let mut ptr = crate::Stack::Stack::new(&mut *(0x800000000000 as *mut u64));
                    ptr.Write::<u64>(0);
                    ptr.Write::<u64>(0x2000);
                    ptr.Write::<u64>(0);
                    ptr.Write::<u64>(0x1000);
                    ptr.Write::<u64>(if argv.is_some() {argv.unwrap().len() as u64} else {0});
                    proc.task_state.SetSP(0x800000000000);
                }
                proc.fds.retain(|_,x| !x.close_on_exec);
                let state_ptr = &proc.task_state as *const State as usize;
                drop(plock);
                drop(argv);
                drop(envp);
                Scheduler::Tick(CurrentHart(),unsafe {&*(state_ptr as *const State)});
                unreachable!();
            }
            Err(e) => {
                drop(argv);
                drop(envp);
                drop(plock);
                return e as usize;
            }
        }
    }
}

pub fn PageFault(pid: i32, location: usize) -> bool {
    let mut lock = PROCESSES.lock();
    let proc = lock.get_mut(&pid).unwrap();
    if (0x7f8000000000..0x800000000000).contains(&(location)) { // Stack Allocation
        if proc.pagetable.GetEntry((location.div_floor(0x1000) * 0x1000) as u64).is_none() {
            log::debug!("Allocated Stack Page Frame via Page Fault.");
            let mut page = Arc::get_mut(&mut proc.pagetable).unwrap().Map((location.div_floor(0x1000) * 0x1000) as u64,crate::PageFrame::Allocate(0x1000).unwrap() as u64-crate::arch::PHYSMEM_BEGIN);
            page.SetUser(true);
            page.SetWritable(true);
            page.SetExecutable(false);
            page.Update();
            drop(lock);
            return true;
        }
        drop(lock);
        return false;
    } else {
        drop(lock);
        return false;
    }
}