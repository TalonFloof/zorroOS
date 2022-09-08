/*
The free list allocator used here is adopted from eduOS-rs.
The original source code can be found here: https://github.com/RWTH-OS/eduOS-rs/blob/master/src/mm/freelist.rs
eduOS-rs is dual licensed under either the Apache License 2.0 or the MIT License.
*/
use static_linkedlist::{Clear, StaticLinkedListBackingArray};
use alloc::collections::LinkedList;

struct EntryClear(pub u64,pub u64);

impl Clear for EntryClear {
    fn clear(&mut self) {
        self.0 = 0;
        self.1 = 1;
	}
}

const FREEALLOC_BUFFER_SIZE: usize = StaticLinkedListBackingArray::<EntryClear>::capacity_for(64);

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