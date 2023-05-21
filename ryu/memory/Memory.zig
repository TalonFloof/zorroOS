pub const PFN = @import("PFN.zig");
const HAL = @import("hal");

pub const PhysicalRange = struct {
    start: usize = 0,
    end: usize = 0,
};

pub fn Initialize(ranges: [32]PhysicalRange) void {
    var highestAddress: usize = 0;
    for (ranges) |r| {
        if (r.end > highestAddress) {
            highestAddress = r.end;
        }
    }
    HAL.Console.Put("Preparing PFN Database [{d} entries, {d} KiB]...\n", .{ highestAddress / 4096, ((highestAddress / 4096) * @sizeOf(PFN.PFNEntry)) / 1024 });
}
