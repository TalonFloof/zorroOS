use alloc::collections::btree_map::BTreeMap;
use alloc::collections::VecDeque;
use core::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use spin::mutex::Mutex;
use crate::arch::Task::State;
use crate::IdleThread;
use crate::Process::{Process, PROCESSES, TaskState, TaskFloatState, ProcessStatus};
use crate::arch::CurrentHart;
use alloc::vec::Vec;

pub static SCHEDULERS: Mutex<BTreeMap<u32,Scheduler>> = Mutex::new(BTreeMap::new());
pub static SCHEDULER_STARTED: AtomicBool = AtomicBool::new(false);

pub struct Scheduler {
    pub current_proc_id: AtomicI32,
    pub process_queue: Mutex<VecDeque<i32>>,
    pub idle_thread: State,
}

impl Scheduler {
    pub fn new() -> Self {
        let mut state = State::new(true);
        state.SetIP((IdleThread as *const fn()) as usize);
        let mut queue = VecDeque::new();
        queue.push_back(-1i32);
        Self {
            current_proc_id: AtomicI32::new(-1i32),
            process_queue: Mutex::new(queue),
            idle_thread: state,
        }
    }
    fn FindNextProcess(&self) -> i32 {
        let mut pqlock = self.process_queue.lock();
        loop {
            let val = *(pqlock.front().unwrap());
            pqlock.rotate_left(1);
            if val != -1i32 {
                let mut plock = PROCESSES.lock();
                match plock.get_mut(&val) {
                    Some(proc) => {
                        match proc.status {
                            ProcessStatus::RUNNABLE => {
                                drop(pqlock);
                                drop(plock);
                                return val;
                            }
                            ProcessStatus::SIGNAL(ip, sig) => {
                                proc.task_state.SetIP(ip);
                                proc.task_state.SetSC1(sig);
                                proc.status = ProcessStatus::RUNNABLE;
                                drop(pqlock);
                                drop(plock);
                                return val;
                            }
                            ProcessStatus::FINISHING(status) => {
                                if proc.children.len() == 0 {
                                    proc.status = ProcessStatus::FINISHED(status);
                                }
                                drop(plock);
                                continue;
                            }
                            ProcessStatus::FORCEKILL(false) => {
                                if proc.children.len() > 0 {
                                proc.status = ProcessStatus::FORCEKILL(true);
                                let children: Vec<i32> = proc.children.clone();
                                drop(plock);
                                    let mut plock = PROCESSES.lock();
                                    for i in children.iter() {
                                        if let Some(child) = plock.get_mut(&i) {
                                            child.status = ProcessStatus::FORCEKILL(false);
                                        }
                                    }
                                    drop(plock);
                                    continue;
                                }
                                proc.status = ProcessStatus::FORCEKILL(true);
                            }
                            ProcessStatus::FORCEKILL(true) => {
                                if proc.children.len() == 0 {
                                    let parid = proc.parent_id;
                                    if let Some(parent) = plock.get_mut(&parid) {
                                        parent.children.retain(|&x| x != val);
                                    }
                                    drop(plock);
                                    drop(pqlock);
                                    crate::Process::Process::CleanupProcess(val);
                                    pqlock = self.process_queue.lock();
                                    continue;
                                }
                            }
                            _ => {
                                drop(plock);
                                continue;
                            }
                        }
                    }
                    None => {
                        drop(plock);
                        drop(pqlock);
                        log::error!("(hart 0x{:x}) Bad PID {} on queue", CurrentHart(), val);
                        pqlock = self.process_queue.lock();
                        continue;
                    }
                }
            } else {
                drop(pqlock);
                return -1i32;
            }
        }
    }
    fn ContextSwitch(&self, pid: i32) {
        let lock = PROCESSES.lock();
        self.current_proc_id.store(pid, Ordering::SeqCst);
        if pid != -1i32 {
            if lock.get(&pid).is_none() {
                panic!("PID: {}, Attempt to Context Switch to unknown process", pid);
            }
            let task = lock.get(&pid).expect("Attempt to Context Switch to unknown process") as *const Process;
            unsafe { (&*task).task_fpstate.Restore(); }
            drop(lock);
            unsafe { (&*task).ContextSwitch() }
        }
        drop(lock);
        self.idle_thread.Enter();
    }
    pub fn Start(hartid: u32) -> ! {
        let mut writelock = SCHEDULERS.lock();
        let sched = Scheduler::new();
        if CurrentHart() == 0 {
            sched.process_queue.lock().push_front(1);
        }
        writelock.insert(hartid,sched);
        let ptr = writelock.get(&hartid).unwrap() as *const Scheduler;
        drop(writelock);
        unsafe {
            let id = (&*ptr).FindNextProcess();
            SCHEDULER_STARTED.store(true,Ordering::SeqCst);
            (&*ptr).ContextSwitch(id);
            panic!("You'll never see this message, isn't that weird?");
        }
    }
    #[allow(unreachable_code)]
    pub fn Tick(hartid: u32, state: &State) { // When a timer interrupt goes off, call this function.
        let l = SCHEDULERS.lock();
        let sched = l.get(&hartid).unwrap();
        let cur_task = sched.current_proc_id.load(Ordering::SeqCst);
        if cur_task != -1i32 {
            let mut pl = PROCESSES.lock();
            if pl.contains_key(&cur_task) {
                pl.get_mut(&cur_task).unwrap().task_state.Save(&state);
                pl.get_mut(&cur_task).unwrap().task_fpstate.Save();
            }
            drop(pl);
        }
        let ptr = sched as *const Scheduler;
        drop(l);
        /*
        Generally this would be a terrible idea, but since scheduler values are atomic,
        the schedulers aren't deleted after creation, and the values are immutable, this is actually safe,
        and it protects the SCHEDULERS Mutex from deadlocking.
        */
        unsafe { 
            let id = (&*ptr).FindNextProcess();
            (&*ptr).ContextSwitch(id);
        }
        panic!("You'll never see this message, isn't that weird?");
    }
    pub fn CurrentPID() -> i32 {
        let l = SCHEDULERS.lock();
        let sched = l.get(&CurrentHart()).unwrap();
        let pid = sched.current_proc_id.load(Ordering::SeqCst);
        drop(l);
        return pid;
    }
}