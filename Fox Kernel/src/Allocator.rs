use core::alloc::Layout;
use buddy_system_allocator::*;
use crate::PageFrame::Allocate;

#[global_allocator]
static GLOBAL_ALLOCATOR: LockedHeapWithRescue<32> = LockedHeapWithRescue::<32>::new(|heap: &mut Heap<32>, layout: &Layout| {
    let extend_size = layout.size().div_ceil(1048576) * 1048576;
    crate::print!("Expanding kernel heap by {} MiB to prevent OOM...\n", extend_size/1048576);
    let heapspace = Allocate(extend_size as u64);
    if heapspace.is_some() {
        unsafe {heap.add_to_heap(heapspace.unwrap() as usize,heapspace.unwrap() as usize+extend_size);}
    } else {
        crate::oom(*layout);
    }
});