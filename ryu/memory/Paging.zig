const Memory = @import("root").Memory;
const HAL = @import("root").HAL;

pub const PageDirectory = []usize;

pub const MapRead = 1;
pub const MapWrite = 2;
pub const MapExec = 4;
pub const MapSupervisor = 8;
pub const MapNoncached = 16;
pub const MapWriteThru = 32;

pub var initialPageDir: ?PageDirectory = null;

pub fn NewPageDirectory() PageDirectory {
    const page = Memory.PFN.AllocatePage(.PageTable, false, 0).?;
    Memory.PFN.ReferencePage(@ptrToInt(page.ptr));
    return @ptrCast([*]usize, page)[0..512];
}

pub fn MapPage(root: PageDirectory, vaddr: usize, flags: usize, paddr: usize) usize {
    const pte = HAL.PTEEntry{
        .r = @intCast(u1, flags & MapRead),
        .w = @intCast(u1, (flags & MapWrite) >> 1),
        .x = @intCast(u1, (flags & MapExec) >> 2),
        .userSupervisor = @intCast(u1, (flags & MapSupervisor) >> 3),
        .nonCached = @intCast(u1, (flags & MapNoncached) >> 4),
        .writeThrough = @intCast(u1, (flags & MapWriteThru) >> 5),
        .reserved = 0,
        .phys = @intCast(u52, paddr >> 12),
    };
    var i: usize = 0;
    var entries: *void = @ptrCast(*void, root.ptr);
    while (i < HAL.Arch.GetPTELevels()) : (i += 1) {
        const index = @intCast(usize, ((vaddr >> 12) & (@intCast(u64, 0x3fe000000000) >> @intCast(u6, i * 9))) >> (37 - @intCast(u6, i * 9)));
        var entry = HAL.Arch.GetPTE(entries, index);
        if (i + 1 >= HAL.Arch.GetPTELevels()) {
            if (pte.r == 0) {
                HAL.Arch.SetPTE(entries, index, HAL.PTEEntry{});
                Memory.PFN.DereferencePage(@ptrToInt(entries));
                return @ptrToInt(entries) + (index * @sizeOf(Memory.PFN.PFNEntry));
            } else {
                HAL.Arch.SetPTE(entries, index, pte);
                Memory.PFN.ReferencePage(@ptrToInt(entries));
                return @ptrToInt(entries) + (index * @sizeOf(Memory.PFN.PFNEntry));
            }
        } else {
            if (entry.r == 0) {
                // Allocate Page
                var page = Memory.PFN.AllocatePage(.PageTable, false, @ptrToInt(entries) + (index * @sizeOf(usize))).?;
                entry.r = 1;
                entry.w = 1;
                entry.x = 0;
                entry.userSupervisor = pte.userSupervisor;
                entry.nonCached = 0;
                entry.writeThrough = 0;
                entry.phys = @intCast(u52, @ptrToInt(page.ptr));
                Memory.PFN.ReferencePage(@ptrToInt(entries));
                entries = @intToPtr(*void, @ptrToInt(page.ptr));
            } else {
                entries = @intToPtr(*void, @intCast(usize, entry.phys) << 12);
            }
        }
    }
    unreachable;
}

pub fn GetPage(root: PageDirectory, vaddr: usize) HAL.PTEEntry {
    var i: usize = 0;
    var entries: *void = @ptrCast(*void, root.ptr);
    while (i < HAL.Arch.GetPTELevels()) : (i += 1) {
        const index = @intCast(usize, ((vaddr >> 12) & (@intCast(u64, 0x3fe000000000) >> @intCast(u6, i * 9))) >> (37 - @intCast(u6, i * 9)));
        var entry = HAL.Arch.GetPTE(entries, index);
        if (i + 1 >= HAL.Arch.GetPTELevels()) {
            return entry;
        } else {
            if (entry.r == 0) {
                return HAL.PTEEntry{};
            } else {
                entries = @intToPtr(*void, @intCast(usize, entry.phys) << 12);
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
        if (count >= size)
            return address;
    }
    return null;
}
