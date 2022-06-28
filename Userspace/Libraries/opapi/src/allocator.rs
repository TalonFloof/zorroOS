use linked_list_allocator::LockedHeap;
use core::ptr::NonNull;
use core::alloc::{Layout,GlobalAlloc};

struct GlobAllocator {
    lock: LockedHeap,
}

unsafe impl GlobalAlloc for GlobAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let mut lock = self.lock.lock();
        if lock.size() == 0 {
            // Init Heap
            let ptr = crate::syscall::sbrk((layout.size().div_ceil(0x4000) * 0x4000) as isize) as usize;
            lock.init(ptr as *mut u8,layout.size().div_ceil(0x4000) * 0x4000);
        }
        match lock.allocate_first_fit(layout) {
            Ok(ptr) => {
                return ptr.as_ptr();
            }
            _ => {
                crate::syscall::sbrk((layout.size().div_ceil(0x4000) * 0x4000) as isize);
                lock.extend(layout.size().div_ceil(0x4000) * 0x4000);
                drop(lock);
                return self.alloc(layout);
            }
        }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        self.lock.lock().deallocate(NonNull::new(ptr).unwrap(),layout);
    }
}

#[global_allocator]
static GLOBAL: GlobAllocator = GlobAllocator {
    lock: LockedHeap::empty(),
};


#[lang = "oom"]
fn oom(_: Layout) -> ! {
    panic!("Process Heap expansion cannot be satisfied: Out of Memory.");
} 