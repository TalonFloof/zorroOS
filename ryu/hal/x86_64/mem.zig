const limine = @import("limine");
const std = @import("std");
const Memory = @import("root").Memory;
const HAL = @import("root").HAL;

export var memmap_request: limine.MemoryMapRequest = .{};

pub fn init(kfStart: usize, kfEnd: usize) void {
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
    ranges[i].start = kfStart;
    ranges[i].end = kfEnd;
    var initial: usize = asm volatile ("mov %%cr3, %[ret]"
        : [ret] "={rax}" (-> usize),
    ) + 0xffff800000000000;
    Memory.Initialize(&ranges, @as([*]usize, @ptrFromInt(initial))[0..512]);
}
