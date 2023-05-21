const HAL = @import("hal");
const Memory = @import("root").Memory;

pub var pfnDatabase: []PFNEntry = undefined;
pub var pfnFreeHead: ?*PFNEntry = null;

// PFN Database
pub const PFNEntry = struct {
    prev: ?*PFNEntry = null,
    next: ?*PFNEntry = null,
    refs: i28 = 0,
    state: u3 = 0,
    swappable: u1 = 0,
    pte: HAL.Arch.PTEEntry,
};

pub fn Initialize(begin: usize, entryCount: usize, ranges: *[32]Memory.PhysicalRange) void {
    _ = ranges;
    pfnDatabase = @intToPtr([*]PFNEntry, begin)[0..entryCount];
    for (0..pfnDatabase.len) |i| {
        pfnDatabase[i].prev = null;
        pfnDatabase[i].next = null;
        pfnDatabase[i].refs = 0;
        pfnDatabase[i].state = 2; // Reserved
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
