const native = @import("native");
const Spinlock = @import("spinlock.zig").Spinlock;
const std = @import("std");
const Thread = @import("thread.zig").Thread;

pub var hartList: ?[]*HardwareThread = null;

pub const HardwareThread = struct {
    kstack: *void,
    id: u32,
    // Scheduling Data
    threadLock: Spinlock = Spinlock.unaquired,
    threadHead: ?*Thread = null,
    threadTail: ?*Thread = null,
    threadCurrent: u64 = 0,
    // Arch Data
    archData: native.hart.HartData,
};
