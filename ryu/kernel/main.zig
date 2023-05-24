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
    // Well It's the momment we've been waiting for
    var mem = Memory.Pool.StaticPool.Alloc(32);
    if (mem) |m| {
        HAL.Console.Put("Allocator Returned: 0x{x}\n", .{@ptrToInt(m.ptr)});
    } else {
        HAL.Console.Put("Allocator Returned: null\n", .{});
    }
    HAL.Console.Put("Boot Complete!\n", .{});
    while (true) {}
}
