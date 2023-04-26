const std = @import("std");

pub const MemEntry = struct {
    begin: usize = 0,
    end: usize = 0,
};

pub var entries: [256]MemEntry = [_]MemEntry{MemEntry{ .begin = 0, .end = 0 }} ** 256;

fn getFreeEntry() usize {
    for (entries, 0..) |entry, index| {
        if (entry.begin == 0 and entry.end == 0) {
            return index;
        }
    }
    return ~0;
}

pub fn alloc(n: usize, alignment: usize) []u8 {
    _ = alignment;
    for (entries, 0..) |entry, index| {
        if ((entry.end - entry.begin) > n) {
            entries[index].begin += n;
            return @intToPtr([*]u8, entries[index].begin - n)[0..n];
        } else if ((entry.end - entry.begin) == n) {
            var ret: []u8 = @intToPtr([*]u8, entries[index].begin)[0..n];
            entries[index].begin = 0;
            entries[index].end = 0;
            return ret;
        }
    }
    @panic("Out of Memory!");
}

pub fn free(d: []u8) void {
    _ = d;
}
