const std = @import("std");
const Spinlock = @import("root").Spinlock;
const Thread = @import("root").Executive.Thread;

pub const EventQueue = struct {
    listLock: Spinlock = .unaquired,
    threadHead: ?*void,

    pub fn Wait(t: *Thread) void {
        _ = t;
    }

    pub fn Wakeup() void {}
};
