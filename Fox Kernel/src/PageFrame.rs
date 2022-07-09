use core::sync::atomic;
use core::sync::atomic::AtomicU64;
use log::{debug,info};
use lazy_static::lazy_static;
use spin::Mutex;
use crate::arch::PHYSMEM_BEGIN;
use crate::arch::Memory::PageTableImpl;
use core::marker::PhantomData;
use alloc::collections::LinkedList;
use core::cmp::Ordering;

pub struct FreeAlloc(pub LinkedList<(usize,usize)>);

impl FreeAlloc {
	pub const fn new() -> Self {
		Self(LinkedList::new())
    }
    pub unsafe fn Allocate(&mut self, size: usize) -> Option<usize> {
        let mut c = self.0.cursor_front_mut();
        while let Some(i) = c.current() {
            match (i.1-i.0).cmp(&size) {
                Ordering::Greater => {
                    let start = i.0;
                    i.0 += size;
                    return Some(start);
                }
                Ordering::Equal => {
                    let start = (&mut c).remove_current().unwrap().0;
					return Some(start);
                }
                _ => {}
            }
            c.move_next();
        }
        None
    }
    pub unsafe fn Free(&mut self, address: usize, size: usize) {
        let mut c = self.0.cursor_front_mut();
        while let Some(i) = c.current() {
            let (start, end) = (i.0, i.1);
            if start == address+size {
                i.0 = address;
                if let Some(p) = c.peek_prev() {
                    if p.1 == address {
                        p.1 = end;
                        c.remove_current();
                    }
                }
                return
            } else if end == address {
                i.1 = address+size;
                if let Some(n) = c.peek_next() {
                    if n.0 == address+size {
                        n.0 = start;
                        c.remove_current();
                    }
                }
                return
            } else if address+size < start {
                c.insert_before((address,address+size));
                return;
            }
            c.move_next();
        }
        self.0.push_back((address,address+size));
    }
}

pub static UsedMem: AtomicU64 = AtomicU64::new(0);
pub static TotalMem: AtomicU64 = AtomicU64::new(0);
pub static FRAME_ALLOC: Mutex<FreeAlloc> = Mutex::new(FreeAlloc::new());
lazy_static! {
    pub static ref KernelPageTable: Mutex<PageTableImpl> = Mutex::new(PageTableImpl::new());
}

pub fn Allocate(size: u64) -> Option<*mut u8> {
    let mut lock = FRAME_ALLOC.lock();
    return match unsafe {lock.Allocate(size as usize)} {
        Some(val) => {
            drop(lock);
            UsedMem.fetch_add(size,atomic::Ordering::SeqCst);
            unsafe {core::ptr::write_bytes(val as *mut u8,0x00,size as usize);}
            Some(val as *mut u8)
        }
        None => {
            drop(lock);
            None
        }
    }
}

pub fn Free(address: *mut u8, size: u64) {
    unsafe {FRAME_ALLOC.lock().Free(address as usize,size as usize);}
    UsedMem.fetch_sub(size as u64,atomic::Ordering::SeqCst);
}

pub fn Setup(mem: [(u64, u64); 32]) {
    for i in mem.iter() {
        if i.1 != 0 {
            unsafe {FRAME_ALLOC.lock().Free((i.0+PHYSMEM_BEGIN) as usize,i.1 as usize);}
            TotalMem.fetch_add(i.1,atomic::Ordering::SeqCst);
        }
    }
    let lock = FRAME_ALLOC.lock();
    let mut c = lock.0.cursor_front();
    while let Some(i) = c.current() {
        log::debug!("Free List Frame: 0x{:016x}-0x{:016x}", i.0, i.1);
        c.move_next();
    }
    drop(lock);
}