use alloc::collections::btree_map::BTreeMap;
use alloc::collections::VecDeque;
use core::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use spin::mutex::Mutex;
use crate::arch::Task::State;
use crate::InitThread;
use crate::Process::{Process, PROCESSES, TaskState, TaskFloatState, ProcessStatus};
use crate::arch::CurrentHart;

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
        state.SetIP((InitThread as *const fn()) as usize);
        let mut queue = VecDeque::new();
        queue.push_back(-1i32);
        Self {
            current_proc_id: AtomicI32::new(0),
            process_queue: Mutex::new(queue),
            idle_thread: state,
        }
    }
    fn FindNextProcess(&self) -> i32 {
        let mut pqlock = self.process_queue.lock();
        let val = *(pqlock.front().unwrap());
        pqlock.rotate_left(1);
        let plock = PROCESSES.lock();
        if val != -1i32 {
            let proc = plock.get(&val).unwrap();
            match proc.status {
                ProcessStatus::RUNNABLE => {
                    drop(plock);
                    drop(pqlock);
                    return val;
                }
                _ => {
                    drop(pqlock);
                    drop(plock);
                    return self.FindNextProcess();
                }
            };
        } else {
            drop(plock);
            drop(pqlock);
            return -1i32;
        }
    }
    fn ContextSwitch(&self, pid: i32) -> ! {
        let lock = PROCESSES.lock();
        self.current_proc_id.store(pid, Ordering::SeqCst);
        if pid != -1i32 {
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
        writelock.insert(hartid,sched);
        let ptr = writelock.get(&hartid).unwrap() as *const Scheduler;
        drop(writelock);
        unsafe {
            let id = (&*ptr).FindNextProcess();
            SCHEDULER_STARTED.store(true,Ordering::SeqCst);
            (&*ptr).ContextSwitch(id);
        }
    }
    #[allow(unreachable_code)]
    pub fn Tick(hartid: u32, state: &State) { // When a timer interrupt goes off, call this function.
        let l = SCHEDULERS.lock();
        let sched = l.get(&hartid).unwrap();
        let cur_task = sched.current_proc_id.load(Ordering::SeqCst);
        if cur_task != -1i32 {
            let mut pl = PROCESSES.lock();
            pl.get_mut(&cur_task).unwrap().task_state.Save(&state);
            pl.get_mut(&cur_task).unwrap().task_fpstate.Save();
            drop(pl);
        }
        let ptr = sched as *const Scheduler;
        drop(l);
        /*
        Generally this would be a terrible idea, but since scheduler values are atomic,
        the schedulers aren't deleted after creation, and the values are immutable, this is actually safe,
        and it protects the SCHEDULERS Mutex from deadlocking.
        */
        unsafe { (&*ptr).NextContext(); }
        unreachable!("You'll never see this message, isn't that weird?");
    }
    pub fn NextContext(&self) -> ! {
        let id = self.FindNextProcess();
        self.ContextSwitch(id);
    }
    pub fn CurrentPID() -> i32 {
        let l = SCHEDULERS.lock();
        let sched = l.get(&CurrentHart()).unwrap();
        let pid = sched.current_proc_id.load(Ordering::SeqCst);
        drop(l);
        return pid;
    }
}