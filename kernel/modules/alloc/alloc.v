module alloc

import ksync
import list_alloc as alloc_impl

__global (
	allocation_lock ksync.Lock
)

fn init() {
	allocation_lock = ksync.Lock{l: ksync.Atomic{value: 0}, id: "ZorroMemoryAllocationLock"}
}

pub fn init_workaround() {
	init()
}

[export: 'init_global_allocator']
pub fn global_alloc_stub() {}