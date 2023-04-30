const native = @import("native");
const std = @import("std");
const root = @import("root");
const HardwareThread = root.hart.HardwareThread;
const Spinlock = root.Spinlock;

pub const Thread = struct {
    kstack: [8192]u8 = [_]u8{0} ** 8192,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    id: u64 = 0,
};
