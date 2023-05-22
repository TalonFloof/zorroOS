pub const HAL = @import("hal");
pub const Memory = @import("memory");
pub const Spinlock = @import("Spinlock.zig").Spinlock;
pub const HCB = @import("HCB.zig").HCB;
const std = @import("std");

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    HAL.Console.Put("Fatal Zig Error: {s}\n", .{msg});
    HAL.Crash.Crash(.RyuZigPanic, .{ 0, 0, 0, 0 });
}

pub export fn RyuInit() noreturn {
    HAL.Console.Put("Boot Complete!\n", .{});
    while (true) {}
}
