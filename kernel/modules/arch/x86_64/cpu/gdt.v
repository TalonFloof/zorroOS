module cpu

[packed]
struct GDTPointer {
	size u16
	address voidptr
}

[packed]
struct GDTEntry {
	limit u16
	base_low u16
	base_mid u8
	access u8
	granularity u8
	base_high u8
}

__global (
	gdt_pointer GDTPointer
	gdt_entries [11]GDTEntry
)

pub fn initialize_gdt() {
	gdt_entries[0] = GDTEntry{
		limit: 0
		base_low: 0
		base_mid: 0
		access: 0
		granularity: 0
		base_high: 0
	}
	gdt_entries[1] = GDTEntry{
		limit: 0xffff
		base_low: 0
		base_mid: 0
		access: 0b10011010
		granularity: 0b00000000
		base_high: 0
	}
	gdt_entries[2] = GDTEntry{
		limit: 0xffff
		base_low: 0
		base_mid: 0
		access: 0b10010010
		granularity: 0b00000000
		base_high: 0
	}
	gdt_entries[3] = GDTEntry{
		limit: 0xffff
		base_low: 0
		base_mid: 0
		access: 0b10011010
		granularity: 0b11001111
		base_high: 0
	}
	gdt_entries[4] = GDTEntry{
		limit: 0xffff
		base_low: 0
		base_mid: 0
		access: 0b10010010
		granularity: 0b11001111
		base_high: 0
	}
	gdt_entries[5] = GDTEntry{
		limit: 0
		base_low: 0
		base_mid: 0
		access: 0b10011010
		granularity: 0b00100000
		base_high: 0
	}
	gdt_entries[6] = GDTEntry{
		limit: 0
		base_low: 0
		base_mid: 0
		access: 0b10010010
		granularity: 0b00000000
		base_high: 0
	}
	gdt_entries[7] = GDTEntry{
		limit: 0
		base_low: 0
		base_mid: 0
		access: 0b11110010
		granularity: 0
		base_high: 0
	}
	gdt_entries[8] = GDTEntry{
		limit: 0
		base_low: 0
		base_mid: 0
		access: 0b11111010
		granularity: 0b00100000
		base_high: 0
	}
	gdt_pointer = GDTPointer{
		size: u16(sizeof(GDTEntry) * 13 - 1)
		address: &gdt_entries
	}
	asm volatile amd64 {
		lgdt ptr
		push rax
		push cseg
		lea rax, [rip + 0x03]
		push rax
		lretq
		pop rax
		mov ds, dseg
		mov es, dseg
		mov ss, dseg
		mov fs, udseg
		mov gs, udseg
		; ; m (gdt_pointer) as ptr
		  rm (u64(0x28)) as cseg
		  rm (u32(0x30)) as dseg
		  rm (u32(0x3b)) as udseg
		; memory
	}
}