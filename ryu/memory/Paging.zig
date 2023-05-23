const Memory = @import("root").Memory;
const HAL = @import("root").HAL;

pub const PageDirectory = []usize;

pub const MapRead = 1;
pub const MapWrite = 2;
pub const MapExec = 4;
pub const MapSupervisor = 8;
pub const MapNoncached = 16;
pub const MapWriteThru = 32;

pub fn NewPageDirectory() PageDirectory {
    const page = Memory.PFN.AllocatePage(.PageTable, false, 0).?;
    Memory.PFN.ReferencePage(@ptrToInt(page.ptr));
    return @ptrCast([*]usize, page)[0..512];
}

fn MapPage(root: PageDirectory, vaddr: usize, flags: usize, paddr: usize) void {
    const pte = HAL.PTEEntry{
        .r = @intCast(u1, flags & MapRead),
        .w = @intCast(u1, (flags & MapWrite) >> 1),
        .x = @intCast(u1, (flags & MapExec) >> 2),
        .userSupervisor = @intCast(u1, (flags & MapSupervisor) >> 3),
        .nonCached = @intCast(u1, (flags & MapNoncached) >> 4),
        .writeThrough = @intCast(u1, (flags & MapWriteThru) >> 5),
        .reserved = 0,
        .phys = @intCast(u52, vaddr >> 12),
    };
    var i = 0;
    var entries: *void = @ptrCast(*void, root.ptr);
    while (i < HAL.Arch.GetPTELevels()) : (i += 1) {
        const index = ((vaddr >> 12) & (0x3fe000000000 >> (i * 9))) >> (37 - (i * 9));
        var entry = HAL.Arch.GetPTE(entries, index);
        if (i + 1 >= HAL.Arch.GetPTELevels()) {
            if (pte.r == 0) {
                HAL.Arch.SetPTE(entries, index, HAL.PTEEntry{});
                Memory.PFN.DereferencePage(paddr);
                Memory.PFN.DereferencePage(@ptrToInt(entries));
            } else {
                HAL.Arch.SetPTE(entries, index, pte);
                Memory.PFN.ReferencePage(paddr);
                Memory.PFN.ReferencePage(@ptrToInt(entries));
            }
        } else {
            if (!entry.r) {
                // Allocate Page
                var page = Memory.PFN.AllocatePage(.PageTable, false, @ptrToInt(entries) + (index * @sizeOf(usize))).?;
                entry.r = 1;
                entry.w = 1;
                entry.x = 0;
                entry.userSupervisor = pte.userSupervisor;
                entry.nonCached = 0;
                entry.writeThrough = 0;
                entry.phys = @intCast(u52, page.ptr);
                Memory.PFN.ReferencePage(@ptrToInt(entries));
                entries = @intToPtr(*void, page.ptr);
            } else {
                entries = @intToPtr(*void, @intCast(usize, entry.phys) << 12);
            }
        }
    }
}
