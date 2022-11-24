module pmm

import limine
import utils

pub fn C.kfree(addr voidptr, n usize)

[cinit]
__global (
	volatile memmap_request = limine.LimineMemMapRequest{response: 0}
)

[manualfree] // utils.itoa confuses the V compiler because it thinks the V string are allocated on the heap, when it's actualy on the stack. That's why this is here.
pub fn initialize() {
	mut membuf := [u8(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]!
	if usize(memmap_request.response) == 0 {
		panic("Limine didn't pass a valid memory map, cannot continue booting!")
	}
	logger := zorro_arch.get_logger() or { panic("No logger? (Imagine putting a meme in a panic message)") }
	entries := memmap_request.response.entries
	for ind := 0; ind < memmap_request.response.entry_count; ind++ {
		unsafe {
			logger.raw_log("Memory map entry No. ")
			logger.raw_log(utils.itoa(u64(ind),mut &membuf,10))
			logger.raw_log(": Base: 0x")
			logger.raw_log(utils.itoa(entries[ind].base,mut &membuf,16))
			logger.raw_log(" | Length: 0x")
			logger.raw_log(utils.itoa(entries[ind].length,mut &membuf,16))
			logger.raw_log(" | Type: ")
			match (&entries[ind]).@type {
				0 {
					logger.raw_log("Usable\n")
					C.kfree((&entries[ind]).base,(&entries[ind]).length)
				}
				1 {
					logger.raw_log("Reserved\n")
				}
				2 {
					logger.raw_log("ACPI Reclaimable\n")
				}
				3 {
					logger.raw_log("ACPI NVS\n")
				}
				4 {
					logger.raw_log("Bad Memory\n")
				}
				5 {
					logger.raw_log("Bootloader Reclaimable\n")
				}
				6 {
					logger.raw_log("Kernel and Modules\n")
				}
				7 {
					logger.raw_log("Framebuffer\n")
				}
				else {
					logger.raw_log("Unknown (Bootloader Bug?)\n")
				}
			}
		}
	}
}