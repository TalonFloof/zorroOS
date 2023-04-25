// This is an extremely primative memory allocator.
// This is only used until we've entered userspace.
// After that, we must use the Sigma Server to obtain memory.
const std = @import("std");

pub const MemEntry = struct {
    begin: usize = 0,
    end: usize = 0,
};

pub var entries: [32]MemEntry = [_]MemEntry{MemEntry{ .begin = 0, .end = 0 }} ** 32;

pub fn alloc(n: usize) []u8 {
    for (entries, 0..) |entry, index| {
        if ((entry.end - entry.begin) > n) {
            entries[index].begin += n;
            std.log.info("0x{x}", .{entries[index].begin - n});
            return @intToPtr([*]u8, entries[index].begin - n)[0..n];
        } else if ((entry.end - entry.begin) == n) {
            std.log.info("0x{x}", .{entries[index].begin});
            var ret: []u8 = @intToPtr([*]u8, entries[index].begin)[0..n];
            entries[index].begin = 0;
            entries[index].end = 0;
            return ret;
        }
    }
    @panic("Out of Memory!");
}
