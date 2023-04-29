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
    return ~@as(usize, 0);
}

fn addEntry(begin: usize, end: usize) usize {
    const entry = getFreeEntry();
    if (entry == ~@as(usize, 0)) {
        return ~@as(usize, 0);
    }
    entries[entry].begin = begin;
    entries[entry].end = end;
    return entry;
}

pub fn alloc(n: usize, alignment: usize) []u8 {
    for (entries, 0..) |entry, index| {
        if ((entry.end - entry.begin) > n) {
            if (alignment > 0) {
                const new_addr = (entry.begin + (alignment - 1)) & ~(alignment - 1);
                entries[index].begin += n + (new_addr - entry.begin);
                if (new_addr != entry.begin) {
                    _ = addEntry(entry.begin, new_addr);
                }
                return @intToPtr([*]u8, new_addr)[0..n];
            } else {
                entries[index].begin += n;
                return @intToPtr([*]u8, entries[index].begin - n)[0..n];
            }
        } else if ((entry.end - entry.begin) == n) {
            if (alignment > 0) {
                const new_addr = (entry.begin + (alignment - 1)) & ~(alignment - 1);
                if (new_addr != entry.begin) {
                    entries[index].end = new_addr;
                }
                return @intToPtr([*]u8, new_addr)[0..n];
            } else {
                var ret: []u8 = @intToPtr([*]u8, entries[index].begin)[0..n];
                entries[index].begin = 0;
                entries[index].end = 0;
                return ret;
            }
        }
    }
    @panic("Kernel Heap is deprived! (Out of Memory)");
}

pub fn free(d: []u8) void {
    const end: usize = @ptrToInt(d.ptr) + d.len;
    for (entries, 0..) |entry, index| {
        if (entry.begin == end) {
            entries[index].begin = @ptrToInt(d.ptr);
            for (entries, 0..) |e, i| {
                if (e.end == @ptrToInt(d.ptr)) {
                    entries[i].end = entry.end;
                    entries[index].begin = 0;
                    entries[index].end = 0;
                    break;
                }
            }
            return;
        } else if (entry.end == @ptrToInt(d.ptr)) {
            entries[index].begin = end;
            for (entries, 0..) |e, i| {
                if (e.begin == end) {
                    entries[i].begin = entry.begin;
                    entries[index].begin = 0;
                    entries[index].end = 0;
                    break;
                }
            }
            return;
        } else if (end < entry.begin) {
            _ = addEntry(@ptrToInt(d.ptr), end);
            return;
        }
    }
    _ = addEntry(@ptrToInt(d.ptr), end);
}
