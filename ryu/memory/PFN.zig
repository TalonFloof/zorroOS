const HAL = @import("hal");
const Memory = @import("root").Memory;

pub var pfnDatabase: []PFNEntry = undefined;
pub var pfnFreeHead: ?*PFNEntry = null;

// PFN Database
pub const PFNEntry = struct {
    next: ?*PFNEntry = null,
    refs: i28 = 0,
    state: u3 = 0,
    swappable: u1 = 0,
    pte: HAL.Arch.PTEEntry,
};

fn isPageFree(addr: usize, ranges: *[32]Memory.PhysicalRange) bool {
    for (ranges) |r| {
        if (r.start == 0 and r.end == 0)
            continue;
        if (r.start >= addr and r.end <= addr + 0xfff) {
            return true;
        }
    }
    return false;
}

pub fn Initialize(begin: usize, entryCount: usize, ranges: *[32]Memory.PhysicalRange) void {
    pfnDatabase = @intToPtr([*]PFNEntry, begin)[0..entryCount];
    for (0..pfnDatabase.len) |i| {
        if (isPageFree(@intCast(usize, i) << 12, ranges)) {
            pfnDatabase[i].next = pfnFreeHead;
            pfnDatabase[i].refs = 0;
            pfnDatabase[i].state = 0; // Free
            pfnFreeHead = &pfnDatabase[i];
        } else {
            pfnDatabase[i].next = null;
            pfnDatabase[i].refs = 0;
            pfnDatabase[i].state = 2; // Reserved
        }
        pfnDatabase[i].swappable = 0;
        pfnDatabase[i].pte.r = 0;
        pfnDatabase[i].pte.w = 0;
        pfnDatabase[i].pte.x = 0;
        pfnDatabase[i].pte.nonCached = 0;
        pfnDatabase[i].pte.writeThrough = 0;
        pfnDatabase[i].pte.reserved = 0;
        pfnDatabase[i].pte.neededLevel = 0;
        pfnDatabase[i].pte.phys = @intCast(u52, i);
    }
}
