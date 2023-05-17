const std = @import("std");
const Spinlock = @import("spinlock.zig").Spinlock;
const alloc = @import("alloc.zig");

pub const Object = struct {
    length: u64 = 0,
    rootDirectory: usize = 0,
    objectName: ?*const u8 = null,
    attributes: u64 = 0,
};
