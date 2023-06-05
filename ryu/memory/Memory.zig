pub const PFN = @import("PFN.zig");
pub const Pool = @import("Pool.zig");
pub const Paging = @import("Paging.zig");
const HAL = @import("hal");

pub const PhysicalRange = struct {
    start: usize = 0,
    end: usize = 0,
};

pub fn Initialize(ranges: *[32]PhysicalRange, initialPD: ?Paging.PageDirectory) void {
    Paging.initialPageDir = initialPD;
    var highestAddress: usize = 0x100000000;
    for (ranges) |r| {
        if (r.end > highestAddress) {
            highestAddress = r.end;
        }
    }
    const entries = highestAddress / 4096;
    const neededSize: usize = ((entries * @sizeOf(PFN.PFNEntry)) & (~@intCast(usize, 0xFFF))) + (if (((entries * @sizeOf(PFN.PFNEntry)) % 4096) > 0) 4096 - ((entries * @sizeOf(PFN.PFNEntry)) % 4096) else 0);
    var startAddr: usize = 0;
    for (ranges, 0..) |r, i| {
        if ((r.end - r.start) > neededSize) {
            startAddr = r.start;
            ranges[i].start += neededSize;
            break;
        } else if ((r.end - r.start) == neededSize) {
            startAddr = r.start;
            ranges[i].start = 0;
            ranges[i].end = 0;
            break;
        }
    }
    if (startAddr == 0) {
        HAL.Crash.Crash(.RyuPFNCorruption, .{ 0xdeaddeaddeaddead, 0, 0, 0 });
    }
    HAL.Console.Put("Preparing PFN Database [{d} entries, {d} KiB, 0x{x:0>16}]...\n", .{ entries, neededSize / 1024, startAddr });
    PFN.Initialize(startAddr, entries, ranges);
}
