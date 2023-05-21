const limine = @import("limine");
const std = @import("std");
const Memory = @import("root").Memory;

export var memmap_request: limine.MemoryMapRequest = .{};

pub fn init() void {
    var ranges: [32]Memory.PhysicalRange = [_]Memory.PhysicalRange{.{ .start = 0, .end = 0 }} ** 32;
    var i: usize = 0;
    if (memmap_request.response) |response| {
        for (response.entries()) |entry| {
            if (entry.kind == .usable) {
                ranges[i].start = entry.base;
                ranges[i].end = entry.base + entry.length;
                i += 1;
            }
        }
    }
    Memory.Initialize(ranges);
}
