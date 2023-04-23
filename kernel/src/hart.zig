const native = @import("native");
const Spinlock = @import("spinlock.zig").Spinlock;
const std = @import("std");
const Thread = @import("thread.zig").Thread;

pub const HardwareThread = struct {
    kstack: [3072]u8,
    id: u32,
    // Scheduling Data
    threadLock: Spinlock = Spinlock.unaquired,
    threadHead: ?*Thread = null,
    threadTail: ?*Thread = null,
    // Arch Data
    archData: native.hart.HartData,

    comptime {
        std.debug.assert(@sizeOf(@This()) <= 4096);
    }
};
