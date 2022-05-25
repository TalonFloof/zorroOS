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

pub static PROCESSES: Mutex<BTreeMap<i32,Process>> = Mutex::new(BTreeMap::new());
pub static NEXTPROCESS: AtomicI32 = AtomicI32::new(0);

pub enum ProcessStatus {
    NEW,
    RUNNABLE,
    SLEEP_IO(Arc<dyn crate::FS::VFS::Inode>,usize,usize),
    SLEEP_WAIT(i32,usize),
    SLEEP_SLEEP(i64),
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

    pub task_state: State,
    pub task_fpstate: FloatState,

    pub hart: AtomicU32,
    pub name: String,

    pub ruid: u32,
    pub rgid: u32,
    pub euid: u32,
    pub egid: u32,

    pub pagetable: Arc<dyn PageTable>,

    pub cwd: String,
    pub status: ProcessStatus,

    pub syscall_stack_base: usize,
}

pub const USERSPACE_STACK_SIZE: u64 = 0x4000;

impl Process {
    pub fn new(name: String) -> Self {
        let state = State::new(false);
        Self {
            id: i32::MIN,

            task_state: state,
            task_fpstate: FloatState::new(),

            hart: AtomicU32::new(u32::MAX),
            name,

            ruid: 0,
            rgid: 0,
            euid: 0,
            egid: 0,
            
            pagetable: Arc::new(PageTableImpl::new()),

            cwd: String::from("/"),
            status: ProcessStatus::NEW,

            syscall_stack_base: (crate::PageFrame::Allocate(0x4000).unwrap() as usize) + 0x4000,
        }
    }
    pub fn ContextSwitch(&self) -> ! {
        unsafe {self.pagetable.Switch();}
        self.task_state.Enter()
    }
    //////////////////////////////////////////////////////////////
    #[allow(dead_code)]
    fn AddProcess(mut proc: Process) -> i32 {
        let mut plock = PROCESSES.lock();
        let start = NEXTPROCESS.load(Ordering::SeqCst);
        let len = *plock.last_key_value().unwrap_or_else(|| (&0, &proc)).0 + 1;
        for i in start..=len {
            if !(plock.contains_key(&i)) {
                proc.id = i;
                plock.insert(i,proc);
                NEXTPROCESS.store(i,Ordering::SeqCst);
                drop(plock);
                return i;
            }
        }
        panic!("Process wasn't added");
    }
    //////////////////////////////////////////////////////////////
    pub fn DestroyProcess(pid: i32) {
        let mut lock = PROCESSES.lock();
        let proc = lock.get_mut(&pid).unwrap();
        let slock = SCHEDULERS.lock();
        if slock.get(&CurrentHart()).unwrap().current_proc_id.load(Ordering::SeqCst) == pid {
            proc.task_state.Exit();
        }
        for i in slock.iter() {
            let mut pqlock = i.1.process_queue.lock();
            if pqlock.contains(&pid) {
                pqlock.retain(|&x| x != pid);
                drop(pqlock);
                break;
            }
            drop(pqlock);
        }
        drop(slock);
        crate::PageFrame::Free((proc.syscall_stack_base - 0x4000) as *mut u8,0x4000);
        lock.remove(&pid);
        drop(lock);
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
    pub fn Fork(&mut self, is_thread: bool) -> Self {
        let mut task_state = State::new(false);
        task_state.Save(&self.task_state);
        task_state.SetSC0(0);
        Self {
            id: i32::MIN,

            task_state,
            task_fpstate: self.task_fpstate.Clone(),

            hart: AtomicU32::new(u32::MAX),
            name: self.name.clone(),

            ruid: self.ruid,
            rgid: self.rgid,
            euid: self.euid,
            egid: self.egid,

            pagetable: self.pagetable.Clone(is_thread),

            cwd: self.cwd.clone(),
            status: ProcessStatus::NEW,

            syscall_stack_base: (crate::PageFrame::Allocate(0x4000).unwrap() as usize) + 0x4000,
        }
    }
}