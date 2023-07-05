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
            if (entry.kind == .usable or entry.kind == .bootloader_reclaimable) {
                HAL.Console.Put("0x{x:0>16}-0x{x:0>16} {s}\n", .{ entry.base, entry.base + (entry.length - 1), @tagName(entry.kind) });
            }
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

fn reserve(page: usize) void {
    var i: ?*Memory.PFN.PFNEntry = Memory.PFN.pfnFreeHead.?;
    var prev: ?*Memory.PFN.PFNEntry = null;
    while (i) |entry| {
        if (((@intFromPtr(entry) - @intFromPtr(Memory.PFN.pfnDatabase.ptr)) / @sizeOf(Memory.PFN.PFNEntry)) == (page >> 12)) {
            if (prev) |p| {
                p.next = entry.next;
            } else {
                Memory.PFN.pfnFreeHead = entry.next;
            }
            entry.next = null;
            entry.state = .Reserved;
            entry.swappable = 0;
            entry.refs = 0;
            entry.pte = 0;
            return;
        }
        prev = entry;
        i = entry.next;
    }
    HAL.Console.Put("WARNING: Couldn't find entry!\n", .{});
}

pub fn reclaim() void {
    HAL.Console.Put("Reclaiming Limine Bootloader Data...\n", .{});
    if (memmap_request.response) |response| {
        for (response.entries()) |entry| {
            if (entry.kind == .bootloader_reclaimable) {
                var i: usize = @intCast(entry.base);
                while (i < @as(usize, @intCast(entry.base + entry.length))) : (i += 4096) {
                    if (Memory.PFN.GetPage(i).state == .Reserved) {
                        Memory.PFN.ForceFreePage(i);
                    }
                }
            }
        }
    }
    // Now iterate through the page table and reserve those pages
    reserve(@intFromPtr(Memory.Paging.initialPageDir.?.ptr) - 0xffff800000000000);
    var curLevel: usize = 0;
    var ptr: [4]?[]usize = .{ Memory.Paging.initialPageDir.?, null, null, null };
    var index: [4]usize = .{ 256, 0, 0, 0 };
    while (!(curLevel == 0 and index[curLevel] >= 512)) {
        const entry = ptr[curLevel].?[index[curLevel]];
        if ((entry & 1) != 0 and (entry & 0x80) == 0 and curLevel != 3) {
            if (Memory.PFN.GetPage(entry & 0xfffffffff000).state == .Free) {
                curLevel += 1;
                ptr[curLevel] = @as([*]usize, @ptrFromInt((entry & 0xfffffffff000) + 0xffff800000000000))[0..512];
                index[curLevel] = 0;
                reserve(@intFromPtr(ptr[curLevel].?.ptr) - 0xffff800000000000);
                continue;
            }
        }
        index[curLevel] += 1;
        if (index[curLevel] >= 512 and curLevel != 0) {
            index[curLevel] = 0;
            ptr[curLevel] = null;
            curLevel -= 1;
        }
    }
}
