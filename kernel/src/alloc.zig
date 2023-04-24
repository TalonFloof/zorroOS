// This is an extremely primative memory allocator.
// This is only used until we've entered userspace.
// After that, we must use the Sigma Server to obtain memory.
const std = @import("std");

pub const MemEntry = struct {
    begin: usize = 0,
    end: usize = 0,
};

pub var entries: [32]MemEntry = [32]MemEntry{MemEntry{ .begin = 0, .end = 0 }} ** 32;

pub fn alloc(n: usize) void {
    _ = n;
}
