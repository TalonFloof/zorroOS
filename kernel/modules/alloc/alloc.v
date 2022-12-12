module alloc

import ksync
import list_alloc as alloc_impl

[cinit]
__global (
	allocation_lock = ksync.Lock{l: ksync.Atomic{value: 0}, id: "ZorroMemoryAllocationLock"}
)

[export: 'init_global_allocator']
pub fn global_alloc_stub() {}
