// Code borrowed from Slabmalloc's global allocator example

use core::alloc::{GlobalAlloc, Layout};
use core::ptr::{self, NonNull};
use core::mem::transmute;
use slabmalloc::*;
use spin::Mutex;
use crate::PageFrame::{Allocate, AllocateAlign, Free};

#[global_allocator]
static GLOBAL_ALLOCATOR: SafeZoneAllocator = SafeZoneAllocator(Mutex::new(ZoneAllocator::new()));

struct Pager;

impl Pager {
    fn allocate_page(&mut self) -> Option<&'static mut ObjectPage<'static>> {
        Allocate(0x1000).map(|r| unsafe { transmute(r as usize) })
    }

    #[allow(unused)]
    fn release_page(&mut self, p: &'static mut ObjectPage<'static>) {
        Free(p as *const ObjectPage as *mut u8, 0x1000);
    }

    // We don't have native support for page allocation beyond 4 KiB pages, so allocate 2 MiBs worth of pages.
    fn allocate_large_page(&mut self) -> Option<&'static mut LargeObjectPage<'static>> {
        AllocateAlign(2 * 1024 * 1024).map(|r| unsafe { transmute(r as usize) })
    }

    #[allow(unused)]
    fn release_large_page(&mut self, p: &'static mut LargeObjectPage<'static>) {
        Free(p as *const LargeObjectPage as *mut u8, 2 * 1024 * 1024);
    }
}

static mut PAGER: Pager = Pager;

pub struct SafeZoneAllocator(Mutex<ZoneAllocator<'static>>);

unsafe impl GlobalAlloc for SafeZoneAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        match layout.size() {
            0x1000 => {
                PAGER.allocate_page().expect("OOM") as *mut _ as *mut u8
            }
            0x200000 => {
                PAGER.allocate_large_page().expect("OOM") as *mut _ as *mut u8
            }
            0..=ZoneAllocator::MAX_ALLOC_SIZE => {
                let mut zone_allocator = self.0.lock();
                match zone_allocator.allocate(layout) {
                    Ok(output) => output.as_ptr(),
                    Err(AllocationError::OutOfMemory) => {
                        if layout.size() <= ZoneAllocator::MAX_BASE_ALLOC_SIZE {
                            PAGER.allocate_page().map_or(ptr::null_mut(), |page| {
                                zone_allocator.refill(layout, page).expect("Slabmalloc refused to refill? (Slabmalloc crate contains bugs!!)");
                                zone_allocator.allocate(layout).expect("Slabmalloc failed to refill after second attempt? (Contact author(s) if you're seeing this!)").as_ptr()
                            })
                        } else {
                            PAGER.allocate_large_page().map_or(ptr::null_mut(), |page| {
                                zone_allocator.refill_large(layout, page).expect("Slabmalloc refused to refill? (Slabmalloc crate contains bugs!!)");
                                zone_allocator.allocate(layout).expect("Slabmalloc failed to refill after second attempt? (Contact author(s) if you're seeing this!)").as_ptr()
                            })
                        }
                    }
                    Err(AllocationError::InvalidLayout) => panic!("GlobalAllocator cannot allocate requested size"),
                }
            }
            _ => unimplemented!("Allocator requested memory that is beyond the maximum allocation size"),
        }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        match layout.size() {
            0x1000 => {Free(ptr, 0x1000);}
            0x200000 => {Free(ptr, 2*1024*1024);}
            0..=ZoneAllocator::MAX_ALLOC_SIZE => {
                if let Some(nptr) = NonNull::new(ptr) {
                    self.0.lock().deallocate(nptr, layout).expect("GlobalAllocator refused to free pages? (Contact author(s) if you're seeing this!)");
                } else {
                    // Nothing...
                }

            }
            _ => unimplemented!("Allocator's request to free memory failed..."),
        }
    }
}