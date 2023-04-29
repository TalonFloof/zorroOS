const native = @import("native");
const std = @import("std");
const root = @import("root");
const HardwareThread = root.hart.HardwareThread;
const Spinlock = root.Spinlock;

pub const Thread = struct {
    kstack: [3072]u8 = [_]u8{0} ** 3072,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    prev: ?*Thread,
    next: ?*Thread,
    id: u64,
    hartID: u64,

    comptime {
        std.debug.assert(@sizeOf(@This()) <= 4096);
    }
};

pub fn scheduleNext() noreturn {
    var curHart = root.native.hart.getHart();
    curHart.threadLock.acquire("hart");
}
