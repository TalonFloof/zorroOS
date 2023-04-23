const std = @import("std");
const builtin = @import("builtin");

pub const Spinlock = enum(u8) {
    unaquired = 0,
    aquired = 1,

    pub fn acquire(spinlock: *volatile Spinlock, lockName: []const u8) void {
        var cycles: usize = 0;
        while (cycles < 50000000) : (cycles += 1) {
            if (@cmpxchgWeak(Spinlock, spinlock, .unaquired, .aquired, .Acquire, .Acquire) == null) {
                return;
            }
            std.atomic.spinLoopHint();
        }
        std.log.err("Deadlocked on lock {s}", .{lockName});
        @panic("System is Deadlocked!");
    }

    pub inline fn release(spinlock: *volatile Spinlock) void {
        @atomicStore(Spinlock, spinlock, .unaquired, .Release);
    }
};
