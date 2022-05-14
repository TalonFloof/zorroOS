use core::sync::atomic::{AtomicU64, Ordering};
use crate::print;
use lazy_static::lazy_static;
use spin::Mutex;
use crate::arch::PHYSMEM_BEGIN;
use crate::arch::Memory::PageTableImpl;
use core::marker::PhantomData;

#[derive(Copy, Clone)]
pub struct HeapRange {
    pub base: u64,
    pub length: u64
}

static Bitmap: AtomicU64 = AtomicU64::new(0);
pub static Pages: AtomicU64 = AtomicU64::new(0);
static NextPage: AtomicU64 = AtomicU64::new(0);
pub static FreeMem: AtomicU64 = AtomicU64::new(0);
pub static TotalMem: AtomicU64 = AtomicU64::new(0);
static PhysMemLock: Mutex<PhantomData<()>> = Mutex::new(PhantomData);
lazy_static! {
    pub static ref KernelPageTable: Mutex<PageTableImpl> = Mutex::new(PageTableImpl::new());
}

#[inline(always)]
fn SetBit(bitmap: *mut u32, bit: u64) {
    unsafe { *bitmap.offset((bit >> 5) as isize) |= 1 << (bit & 31); };
}

#[inline(always)]
fn ClearBit(bitmap: *mut u32, bit: u64) {
    unsafe { *bitmap.offset((bit >> 5) as isize) &= !(1 << (bit & 31)); };
}

#[inline(always)]
fn TestBit(bitmap: *mut u32, bit: u64) -> bool {
    unsafe { return ((*bitmap.offset((bit >> 5) as isize)) & (1 << (bit & 31))) != 0; };
}

fn SetRange(Start: u64, End: u64) {
    let page_start = Start / 0x1000;
    let page_end = (End / 0x1000) + (if (End % 0x1000) > 0 {1} else {0});
    let ptr = Bitmap.load(Ordering::Relaxed) as *mut u32;
    for i in page_start..page_end {
        SetBit(ptr,i);
    }
    if page_start == NextPage.load(Ordering::SeqCst) {
        NextPage.store(page_end,Ordering::SeqCst);
    }
}

fn FreeRange(Start: u64, End: u64) {
    let page_start = Start / 0x1000;
    let page_end = (End / 0x1000) + (if (End % 0x1000) > 0 {1} else {0});
    let ptr = Bitmap.load(Ordering::Relaxed) as *mut u32;
    for i in page_start..page_end {
        ClearBit(ptr,i);
    }
    if page_start < NextPage.load(Ordering::SeqCst) {
        NextPage.store(page_start,Ordering::SeqCst);
    }
}

#[inline(always)]
fn TestRange(Addr: u64, Size: u64) -> bool {
    let ptr = Bitmap.load(Ordering::Relaxed) as *mut u32;
    let bit_start = Addr / 0x1000;
    let bit_end = (Size / 0x1000) + bit_start;
    for i in bit_start..bit_end {
        if TestBit(ptr,i) {
            return true;
        }
    }
    return false;
}

// The most important functions...

// XXXX: Should Allocate and Free be unsafe?
pub fn Allocate(Size: u64) -> Option<*mut u8> {
    let lock = PhysMemLock.lock();
    let np = NextPage.load(Ordering::SeqCst);
    let p = Pages.load(Ordering::SeqCst);
    let pages = Size / 0x1000;
    for i in np..(p - pages) {
        if !TestRange(i * 0x1000, Size) {
            SetRange(i * 0x1000, (i * 0x1000)+Size);
            FreeMem.fetch_sub(Size,Ordering::SeqCst);
            drop(lock);
            unsafe {core::ptr::write_bytes(((i*0x1000)+PHYSMEM_BEGIN) as *mut u8,0x00,Size as usize);}
            return Some(((i*0x1000)+PHYSMEM_BEGIN) as *mut u8);
        }
    }
    drop(lock);
    return None;
}
pub fn AllocateAlign(Size: u64) -> Option<*mut u8> {
    let lock = PhysMemLock.lock();
    let np = (NextPage.load(Ordering::SeqCst) * 0x1000) / Size;
    let p = (Pages.load(Ordering::SeqCst) * 0x1000) / Size;
    for i in np..p {
        if !TestRange(i * Size, Size) {
            SetRange(i * Size, (i * Size)+Size);
            FreeMem.fetch_sub(Size,Ordering::SeqCst);
            drop(lock);
            unsafe {core::ptr::write_bytes(((i*Size)+PHYSMEM_BEGIN) as *mut u8,0x00,Size as usize);}
            return Some(((i*Size)+PHYSMEM_BEGIN) as *mut u8);
        }
    }
    drop(lock);
    return None;
}
#[inline(always)]
pub fn Free(Addr: *mut u8, Size: u64) {
    let lock = PhysMemLock.lock();
    if Addr as u64 != 0 {
        FreeRange(Addr as u64-PHYSMEM_BEGIN, ((Addr as u64)-PHYSMEM_BEGIN) + Size);
        FreeMem.fetch_add(Size,Ordering::SeqCst);
    }
    drop(lock);
}

pub fn Setup(mem: [HeapRange; 64]) {
    let mut max_mem: u64 = 0;
    for i in mem.iter() {
        if (i.base + i.length) > max_mem {
            max_mem = i.base + i.length;
        }
    }
    let pages = max_mem / 0x1000;
    let bitmap_size = (pages / 8) + (if pages % 8 > 0 {1} else {0});
    let bm_pages = (bitmap_size / 0x1000) + (if bitmap_size % 0x1000 > 0 {1} else {0});
    Pages.store(pages,Ordering::SeqCst);
    NextPage.store(pages,Ordering::SeqCst);
    print!("Allocating {} pages ({} KiB) for Page Frame Bitmap...\n", bm_pages, bm_pages*4);
    for i in mem.iter() {
        if i.length >= bm_pages * 0x1000 {
            Bitmap.store(PHYSMEM_BEGIN + i.base,Ordering::Relaxed);
            unsafe { core::ptr::write_bytes(Bitmap.load(Ordering::Relaxed) as *mut u8,0xFF,bitmap_size as usize); }
            break;
        }
    }
    for i in mem.iter() {
        FreeRange(i.base,i.base+i.length);
        FreeMem.fetch_add(i.length,Ordering::SeqCst);
        TotalMem.fetch_add(i.length,Ordering::SeqCst);
    }
    let bitmap = Bitmap.load(Ordering::Relaxed);
    assert_ne!(bitmap, 0);
    SetRange(bitmap-PHYSMEM_BEGIN,(bitmap-PHYSMEM_BEGIN)+(bm_pages*0x1000));
    FreeMem.fetch_sub(bm_pages*0x1000,Ordering::SeqCst);
    print!("Page Frame Bitmap located at 0x{:016x}\n", bitmap);
}