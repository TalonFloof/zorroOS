const native = @import("native");
const std = @import("std");
const root = @import("root");
const HardwareThread = @import("hart.zig").HardwareThread;
const Spinlock = @import("spinlock.zig").Spinlock;
const object = @import("object.zig");
const alloc = @import("alloc.zig");

pub const Thread = struct {
    obj: object.Object,
    kstack: [8192]u8 = [_]u8{0} ** 8192,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    managerID: u64 = 0,
    universeID: u64 = 0,
    coreID: u64 = 0,
    startTime: u64 = 0,
    stopTime: u64 = 0,

    pub fn new(man: u64, uni: u64, core: u64) *Thread {
        var thread = @ptrCast(*Thread, @alignCast(@alignOf(usize), alloc.alloc(@sizeOf(Thread), @alignOf(usize)).ptr));
        thread.obj.typ = .Thread;
        thread.obj.decon = decon;
        thread.obj.init();
        thread.managerID = man;
        thread.universeID = uni;
        thread.coreID = core;
        return thread;
    }

    pub fn decon(self: *object.Object) void {
        var thr = @ptrCast(*Thread, self);
        alloc.free(@ptrCast([*]u8, thr)[0..(@sizeOf(Thread) + 1)]);
    }
};
