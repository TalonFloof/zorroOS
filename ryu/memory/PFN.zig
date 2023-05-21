const HAL = @import("hal");
const Memory = @import("root").Memory;

// PFN Database
pub const PFNEntry = struct {
    prev: ?*PFNEntry = null,
    next: ?*PFNEntry = null,
    refs: i28 = 0,
    state: u3 = 0,
    swappable: u1 = 0,
    pte: HAL.Arch.PTEEntry,
};

pub fn Initialize(begin: usize, entryCount: usize, ranges: [32]Memory.PhysicalRange) void {
    _ = ranges;
    @memset(@intToPtr([*]u8, begin)[0..(entryCount * @sizeOf(PFNEntry))], 0);
}
