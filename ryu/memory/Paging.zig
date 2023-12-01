const Memory = @import("root").Memory;
const HAL = @import("root").HAL;
const Executive = @import("root").Executive;

pub const PageDirectory = []usize;

pub const MapRead = 1;
pub const MapWrite = 2;
pub const MapExec = 4;
pub const MapSupervisor = 8;
pub const MapNoncached = 16;
pub const MapWriteThru = 32;
pub const MapWriteComb = 64;

pub var initialPageDir: ?PageDirectory = null;

pub fn NewPageDirectory() PageDirectory {
    const page = Memory.PFN.AllocatePage(.PageTable, false, 0).?;
    Memory.PFN.ReferencePage(@intFromPtr(page.ptr) - 0xffff800000000000);
    var pageDir = @as([*]usize, @ptrCast(@alignCast(page.ptr)))[0..512];
    var i: usize = 256;
    while (i < 512) : (i += 1) {
        pageDir[i] = initialPageDir.?[i];
    }
    return pageDir;
}

fn derefPageTable(pt: *void, level: usize) void {
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        if (level == 0 and i >= 256) {
            break;
        } else if (level + 1 >= HAL.Arch.GetPTELevels()) {
            const pte = HAL.Arch.GetPTE(pt, i);
            if (pte.r != 0) {
                const addr = @as(usize, @intCast(pte.phys)) << 12;
                Memory.PFN.DereferencePage(addr);
                HAL.Arch.SetPTE(pt, 0, HAL.PTEEntry{});
                Memory.PFN.DereferencePage(@intFromPtr(pt) - 0xffff800000000000);
            }
        } else {
            const pte = HAL.Arch.GetPTE(pt, i);
            if (pte.r != 0) {
                derefPageTable(@as(*void, @ptrFromInt((@as(usize, @intCast(pte.phys)) << 12) + 0xffff800000000000)), level + 1);
            }
        }
    }
}

pub inline fn DestroyPageDirectory(root: PageDirectory) void {
    derefPageTable(@as(*void, @ptrCast(root.ptr)), 0);
    Memory.PFN.ForceFreePage(@intFromPtr(root.ptr) - 0xffff800000000000);
}

pub fn MapPage(root: PageDirectory, vaddr: usize, flags: usize, paddr: usize) usize {
    const pte = HAL.PTEEntry{
        .r = @as(u1, @intCast(flags & MapRead)),
        .w = @as(u1, @intCast((flags >> 1) & 1)),
        .x = @as(u1, @intCast((flags >> 2) & 1)),
        .userSupervisor = @as(u1, @intCast((flags >> 3) & 1)),
        .nonCached = @as(u1, @intCast((flags >> 4) & 1)),
        .writeThrough = @as(u1, @intCast((flags >> 5) & 1)),
        .writeCombine = @as(u1, @intCast((flags >> 6) & 1)),
        .reserved = 0,
        .phys = @as(u52, @intCast(paddr >> 12)),
    };
    var i: usize = 0;
    var entries: *void = @as(*void, @ptrCast(root.ptr));
    while (i < HAL.Arch.GetPTELevels()) : (i += 1) {
        const index: u64 = (vaddr >> (39 - @as(u6, @intCast(i * 9)))) & 0x1ff;
        var entry = HAL.Arch.GetPTE(entries, index);
        if (i + 1 >= HAL.Arch.GetPTELevels()) {
            if (pte.r == 0) {
                HAL.Arch.SetPTE(entries, index, HAL.PTEEntry{});
                HAL.Arch.InvalidatePage(vaddr);
                if (entry.r != 0) {
                    Memory.PFN.DereferencePage(@intFromPtr(entries) - 0xffff800000000000);
                }
                return @intFromPtr(entries) + (index * @sizeOf(Memory.PFN.PFNEntry));
            } else {
                HAL.Arch.SetPTE(entries, index, pte);
                HAL.Arch.InvalidatePage(vaddr);
                if (entry.r == 0) {
                    Memory.PFN.ReferencePage(@intFromPtr(entries) - 0xffff800000000000);
                }
                return @intFromPtr(entries) + (index * @sizeOf(Memory.PFN.PFNEntry));
            }
        } else {
            if (entry.r == 0) {
                // Allocate Page
                const page = Memory.PFN.AllocatePage(.PageTable, vaddr < 0x800000000000, @intFromPtr(entries) + (index * @sizeOf(usize))).?;
                entry.r = 1;
                entry.w = 1;
                entry.x = 1;
                entry.userSupervisor = pte.userSupervisor;
                entry.nonCached = 0;
                entry.writeThrough = 0;
                entry.writeCombine = 0;
                entry.phys = @as(u52, @intCast((@intFromPtr(page.ptr) - 0xffff800000000000) >> 12));
                HAL.Arch.SetPTE(entries, index, entry);
                Memory.PFN.ReferencePage(@intFromPtr(entries) - 0xffff800000000000);
                entries = @as(*void, @ptrFromInt(@intFromPtr(page.ptr)));
            } else {
                entries = @as(*void, @ptrFromInt((@as(usize, @intCast(entry.phys)) << 12) + 0xffff800000000000));
            }
        }
    }
    unreachable;
}

pub fn GetPage(root: PageDirectory, vaddr: usize) HAL.PTEEntry {
    var i: usize = 0;
    var entries: *void = @as(*void, @ptrCast(root.ptr));
    while (i < HAL.Arch.GetPTELevels()) : (i += 1) {
        const index: u64 = (vaddr >> (39 - @as(u6, @intCast(i * 9)))) & 0x1ff;
        const entry = HAL.Arch.GetPTE(entries, index);
        if (i + 1 >= HAL.Arch.GetPTELevels()) {
            return entry;
        } else {
            if (entry.r == 0) {
                return HAL.PTEEntry{};
            } else {
                entries = @as(*void, @ptrFromInt((@as(usize, @intCast(entry.phys)) << 12) + 0xffff800000000000));
            }
        }
    }
    unreachable;
}

pub fn FindFreeSpace(root: PageDirectory, start: usize, size: usize) ?usize { // This is only used for the Static and Paged Pools, userspace doesn't use this
    var i = start;
    var address: usize = 0;
    var count: usize = 0;
    while (i < start + (512 * 1024 * 1024 * 1024)) : (i += 4096) {
        if (GetPage(root, i).r != 0) {
            count = 0;
            address = 0;
            continue;
        }
        if (address == 0)
            address = i;
        count += 4096;
        if (count >= size) {
            return address;
        }
    }
    return null;
}

pub const AccessRead = 1;
pub const AccessWrite = 2;
pub const AccessExecute = 4;
pub const AccessSupervisor = 8;
pub const AccessIsValid = 16;

pub fn PageFault(pc: usize, addr: usize, accessType: usize) void {
    if (accessType & AccessSupervisor != 0) {
        if (addr >= 0xfffffe8000000000 and addr <= 0xfffffeffffffffff) {
            HAL.Crash.Crash(.RyuPageFaultInStaticPool, .{ addr, accessType, 0, pc }, null);
        } else {
            HAL.Crash.Crash(.RyuUnhandledPageFault, .{ addr, accessType, 0, pc }, null);
        }
    } else {
        HAL.Console.Put("Userspace Page Fault!! (pc: 0x{x}, addr 0x{x}, accessType: 0x{x})\n", .{ pc, addr, accessType });
    }
}
