#include "gdt.h"

typedef struct __attribute__((packed)) {
	uint16_t size;
	void* address;
} GDTPointer;

typedef struct __attribute__((packed)) {
	uint16_t limit;
	uint16_t base_low;
	uint8_t base_mid;
	uint8_t access;
	uint8_t granularity;
	uint8_t base_high;
} GDTEntry;

GDTPointer gdt_pointer;
GDTEntry gdt_entries[11];

void x86_64_GDT_Initialize() {
  gdt_entries[0] = (GDTEntry){
		.limit=0,
		.base_low=0,
		.base_mid=0,
		.access=0,
		.granularity=0,
		.base_high=0
	};
	gdt_entries[1] = (GDTEntry){
		.limit=0xffff,
		.base_low=0,
		.base_mid=0,
		.access=0b10011010,
		.granularity=0b00000000,
		.base_high=0
	};
	gdt_entries[2] = (GDTEntry){
		.limit=0xffff,
		.base_low=0,
		.base_mid=0,
		.access=0b10010010,
		.granularity=0b00000000,
		.base_high=0
	};
	gdt_entries[3] = (GDTEntry){
		.limit=0xffff,
		.base_low=0,
		.base_mid=0,
		.access=0b10011010,
		.granularity=0b11001111,
		.base_high=0
	};
	gdt_entries[4] = (GDTEntry){
		.limit=0xffff,
		.base_low=0,
		.base_mid=0,
		.access=0b10010010,
		.granularity=0b11001111,
		.base_high=0
	};
	gdt_entries[5] = (GDTEntry){
		.limit=0,
		.base_low=0,
		.base_mid=0,
		.access=0b10011010,
		.granularity=0b00100000,
		.base_high=0
	};
	gdt_entries[6] = (GDTEntry){
		.limit=0,
		.base_low=0,
		.base_mid=0,
		.access=0b10010010,
		.granularity=0b00000000,
		.base_high=0
	};
	gdt_entries[7] = (GDTEntry){
		.limit=0,
		.base_low=0,
		.base_mid=0,
		.access=0b11110010,
		.granularity=0,
		.base_high=0
	};
	gdt_entries[8] = (GDTEntry){
		.limit=0,
		.base_low=0,
		.base_mid=0,
		.access=0b11111010,
		.granularity=0b00100000,
		.base_high=0
	};
  gdt_pointer = (GDTPointer){
		.size=(uint16_t)(sizeof(GDTEntry) * 13 - 1),
		.address=&gdt_entries
	};
  asm volatile (
		"mov %0, %%rdi\n"
		"lgdt (%%rdi)\n"
		"mov $0x30, %%ax\n"
		"mov %%ax, %%ds\n"
		"mov %%ax, %%es\n"
		"mov %%ax, %%ss\n"
		"mov $0x3b, %%ax\n"
		"mov %%ax, %%fs\n"
    "mov %%ax, %%gs"
    :: "r"(&gdt_pointer) : "memory");
}