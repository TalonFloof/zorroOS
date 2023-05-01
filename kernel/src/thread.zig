const native = @import("native");
const std = @import("std");
const root = @import("root");
const HardwareThread = @import("hart.zig").HardwareThread;
const Spinlock = @import("spinlock.zig").Spinlock;
const object = @import("object.zig");

pub const Thread = struct {
    obj: object.Object,
    kstack: []u8,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    id: u64 = 0,
    managerID: u64 = 0,
    startTime: u64 = 0,
    stopTime: u64 = 0,

    pub fn new() *Thread {}
};
