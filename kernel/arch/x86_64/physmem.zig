const std = @import("std");
const limine = @import("limine");

export var memmap_request: limine.MemoryMapRequest = .{};

pub fn initialize() void {
    if (memmap_request.response) |memmap_response| {
        _ = memmap_response;
    } else {
        @panic("Bootloader did not provide a valid memory map!");
    }
}
