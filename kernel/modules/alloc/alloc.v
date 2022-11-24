module alloc

import ksync
import list_alloc as alloc_impl

__global (
	allocation_lock ksync.Lock
)

fn init() {
	allocation_lock = ksync.Lock{l: ksync.Atomic{value: 0}, id: "ZorroMemoryAllocationLock"}
}

pub fn early_init() {
	init()
}