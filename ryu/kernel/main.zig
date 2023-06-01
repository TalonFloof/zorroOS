pub const HAL = @import("hal");
pub const Memory = @import("memory");
pub const Spinlock = @import("Spinlock.zig").Spinlock;
pub const HCB = @import("HCB.zig").HCB;
pub const IRQL = @import("IRQL.zig");
pub const ELF = @import("ELF.zig");
pub const Drivers = @import("Drivers.zig");
pub const KernelSettings = @import("KernelSettings.zig");
const std = @import("std");

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("Fatal Zig Error: {s}\n", .{msg});
    HAL.Crash.Crash(.RyuZigPanic, .{ 0, 0, 0, 0 });
}

pub export fn RyuInit() noreturn {
    HAL.Crash.Crash(.RyuKernelInitializationFailure, .{ 0xb007b007b007b007, 0, 0, 0 });
}

pub inline fn LoadModule(name: []const u8, data: []u8) void {
    Drivers.LoadDriver(name, @ptrCast(*void, data.ptr));
}
