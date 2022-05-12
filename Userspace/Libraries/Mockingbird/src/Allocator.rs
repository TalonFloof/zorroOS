use core::alloc::{GlobalAlloc, Layout};
use core::ptr;
use linked_list_allocator::LockedHeap;

struct GlobAllocator {
    lock: LockedHeap,
}

unsafe impl GlobalAlloc for GlobAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let mut lock = self.lock.lock();
        if lock.size() == 0 {
            // Init Heap
            let ptr = crate::Heap::sbrk((layout.size().div_ceil(0x4000) * 0x4000) as isize) as usize;
            lock.init(ptr,layout.size().div_ceil(0x4000) * 0x4000);
        }
        match lock.allocate_first_fit(layout) {
            Ok(ptr) => {
                return ptr.as_ptr();
            }
            _ => {
                crate::Heap::sbrk((layout.size().div_ceil(0x4000) * 0x4000) as isize);
                lock.extend(layout.size().div_ceil(0x4000) * 0x4000);
                drop(lock);
                return self.alloc(layout);
            }
        }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        self.lock.lock().deallocate(ptr::NonNull::new(ptr).unwrap(),layout);
    }
}

#[global_allocator]
static GLOBAL: GlobAllocator = GlobAllocator {
    lock: LockedHeap::empty(),
};

#[lang = "oom"]
fn oom(_: Layout) -> ! {
    panic!("Heap expansion cannot be satisfied: Out of Memory.");
}