use spin::Mutex;
use lazy_static::lazy_static;

extern "C" {
    fn __heapbase();
}

lazy_static! {
    static ref heap_position: Mutex<u64> = Mutex::new(__heapbase as u64);
}

pub unsafe fn sbrk(size: isize) -> u64 { // Expand Heap Size
    let mut lock = heap_position.lock();
    let pos = *lock;
    if size > 0 {
        let _new_heap_end = *lock + (size as u64);
        let mut pos = *lock;
        for i in 12..usize::BITS {
            if size & (1 << i as u64) == 1 << i {
                crate::Memory::Allocate(u32::MAX,pos as usize,1 << i,true,false);
                pos += 1 << i;
            }
        }
        *lock = _new_heap_end;
    } else if size < 0 {
        let _new_heap_end = *lock - ((size.abs()) as u64);
        let mut pos = *lock;
        for i in 12..usize::BITS {
            if size & (1 << i as u64) == 1 << i {
                crate::Memory::UMap(u32::MAX,pos as usize,1 << i);
                pos -= 1 << i;
            }
        }
        *lock = _new_heap_end;
    }
    drop(lock);
    return pos;
}

/*
Warning!
Brk Doesn't allocate or free pages to/from the heap, it only changes the heap position!
If used incorrectly it can seriously mess up the running program!
*/
pub unsafe fn brk(ptr: usize) { // Set Heap Position
    let mut lock = heap_position.lock();
    *lock = ptr as u64;
    drop(lock);
}