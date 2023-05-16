const native = @import("native");
const Spinlock = @import("spinlock.zig").Spinlock;
const std = @import("std");
const Thread = @import("objects/thread.zig").Thread;

pub var hartList: ?[]*HardwareThread = null;

pub const HardwareThread = struct {
    activeKstack: ?*void = null,
    activeUstack: ?*void = null,
    id: u32,
    // Scheduling Data
    // Arch Data
    archData: native.hart.HartData,
};
