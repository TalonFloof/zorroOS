module api

pub const (
	zorro_object_create = u64(0x44df433d6ec2cfad)
	zorro_object_grant = u64(0xc9969df620c3641d)
	zorro_object_reference = u64(0x890074221b7afef4)
	zorro_object_dereference = u64(0x06756960036071ae)
	zorro_memory_map = u64(0x6c3ff70006c53045)
	zorro_memory_unmap = u64(0x8ba9170c530e1f25)
	zorro_thread_begin_execution = u64(0x6578036eaf605a13)
	zorro_thread_exit = u64(0x136b091b5d834bf4)
	zorro_thread_kill = u64(0x1ef47cdab52acfcf)
	zorro_thread_rights_pledge = u64(0xbe277c5c68052ee1)
	zorro_event_bind = u64(0x52df341a8174f5d9)
)